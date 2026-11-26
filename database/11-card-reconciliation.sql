-- V6: execute após 10-card-analytics.sql. Aditiva: preserva faturas anteriores e RPCs legadas.
begin;
alter table public.fin_card_statements add column if not exists previous_balance_cents bigint not null default 0 check(previous_balance_cents between -99999999999 and 99999999999);
alter table public.fin_card_items add column if not exists movement_type text check(movement_type in ('purchase','fee','credit','payment'));
alter table public.fin_card_items add column if not exists card_last4 text check(card_last4 ~ '^[0-9]{4}$');
alter table public.fin_card_items add column if not exists foreign_usd_cents bigint check(foreign_usd_cents between -99999999999 and 99999999999);
-- NULL para itens legados: sem inferir tipos retroativamente.
create or replace function public.fin_save_card_statement_v6(p_workspace uuid,p_card_id uuid,p_due date,p_total bigint,p_hash text,p_items jsonb,p_existing uuid,p_previous bigint,p_rules jsonb)
returns table(id uuid) language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_entry uuid; v_category uuid; v_sum numeric; v_count integer; v_card text; v_bank text; r record;
begin
 if v_user is null or not exists(select 1 from public.fin_members m where m.workspace_id=p_workspace and m.user_id=v_user) then raise exception 'Ambiente não autorizado' using errcode='42501'; end if;
 select c.name,b.name into v_card,v_bank from public.fin_credit_cards c join public.fin_banks b on b.id=c.bank_id and b.workspace_id=c.workspace_id where c.id=p_card_id and c.workspace_id=p_workspace;
 if v_card is null or p_due is null or p_total is null or p_total not between 1 and 99999999999 or (p_hash is not null and p_hash !~ '^[0-9a-f]{64}$') then raise exception 'Dados da fatura inválidos'; end if;
 if p_previous is null or p_previous not between -99999999999 and 99999999999 then raise exception 'Saldo anterior inválido'; end if;
 if p_rules is null or jsonb_typeof(p_rules)<>'array' or jsonb_array_length(p_rules)>2000 then raise exception 'Regras inválidas'; end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' then raise exception 'Informe os itens'; end if;
 v_count:=jsonb_array_length(p_items); if v_count not between 1 and 2000 then raise exception 'A fatura deve conter de 1 a 2000 itens'; end if;
 select sum(x.amount_cents) into v_sum from jsonb_to_recordset(p_items) as x(purchase_date date,description text,category text,amount_cents bigint,movement_type text,card_last4 text,foreign_usd_cents bigint);
 if v_sum+p_previous is distinct from p_total or exists(select 1 from jsonb_to_recordset(p_items) as x(purchase_date date,description text,category text,amount_cents bigint,movement_type text,card_last4 text,foreign_usd_cents bigint) where x.purchase_date is null or x.purchase_date>p_due or x.description is null or char_length(trim(x.description)) not between 1 and 150 or x.category is null or char_length(trim(x.category)) not between 1 and 60 or x.amount_cents is null or x.amount_cents=0 or x.amount_cents not between -99999999999 and 99999999999 or x.movement_type is null or x.movement_type not in ('purchase','fee','credit','payment') or (x.movement_type in ('credit','payment') and x.amount_cents>=0) or (x.movement_type in ('purchase','fee') and x.amount_cents<=0) or (x.card_last4 is not null and x.card_last4 !~ '^[0-9]{4}$') or (x.foreign_usd_cents is not null and x.foreign_usd_cents not between -99999999999 and 99999999999)) then raise exception 'Itens inválidos ou total divergente'; end if;
 insert into public.fin_categories(workspace_id,kind,name) values(p_workspace,'expense','Cartão de crédito') on conflict(workspace_id,kind,name) do nothing;
 select c.id into strict v_category from public.fin_categories c where c.workspace_id=p_workspace and c.kind='expense' and c.name='Cartão de crédito';
 if p_existing is null then
  insert into public.fin_entries(workspace_id,category_id,kind,description,amount_cents,due_date,status,paid_date,notes,created_by) values(p_workspace,v_category,'expense',left('Fatura • '||v_bank||' / '||v_card,150),p_total,p_due,'pending',null,'Fatura detalhada no módulo Cartões de crédito.',v_user) returning fin_entries.id into v_entry;
 else
  select e.id into v_entry from public.fin_entries e where e.id=p_existing and e.workspace_id=p_workspace and e.kind='expense' and e.amount_cents=p_total and e.due_date=p_due and e.recurring_id is null and not exists(select 1 from public.fin_card_statements s where s.id=e.id) for update;
  if v_entry is null then raise exception 'O lançamento selecionado não corresponde à fatura'; end if;
  update public.fin_entries e set category_id=v_category,description=left('Fatura • '||v_bank||' / '||v_card,150) where e.id=v_entry;
 end if;
 insert into public.fin_card_statements(id,workspace_id,card_id,card_name,due_date,total_cents,source_hash,previous_balance_cents) values(v_entry,p_workspace,p_card_id,v_card,p_due,p_total,p_hash,p_previous);
 insert into public.fin_card_items(statement_id,workspace_id,purchase_date,description,category,amount_cents,movement_type,card_last4,foreign_usd_cents) select v_entry,p_workspace,x.purchase_date,trim(x.description),case when x.movement_type='payment' then 'Pagamentos de fatura' else trim(x.category) end,x.amount_cents,x.movement_type,x.card_last4,x.foreign_usd_cents from jsonb_to_recordset(p_items) as x(purchase_date date,description text,category text,amount_cents bigint,movement_type text,card_last4 text,foreign_usd_cents bigint);
 for r in select * from jsonb_to_recordset(p_rules) as x(merchant_key text,category text) loop
 insert into public.fin_card_rules(workspace_id,merchant_key,category) values(p_workspace,r.merchant_key,r.category) on conflict(workspace_id,merchant_key) do update set category=excluded.category;
 end loop;
 return query select v_entry;
end $$;
revoke all on function public.fin_save_card_statement_v6(uuid,uuid,date,bigint,text,jsonb,uuid,bigint,jsonb) from public,anon,authenticated;
grant execute on function public.fin_save_card_statement_v6(uuid,uuid,date,bigint,text,jsonb,uuid,bigint,jsonb) to authenticated;
commit;

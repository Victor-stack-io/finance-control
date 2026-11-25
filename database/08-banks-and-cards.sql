-- V2: execute após 06. Preserva valores e status das faturas existentes.
begin;
create table public.fin_banks (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.fin_workspaces(id) on delete cascade,
 name text not null check(char_length(trim(name)) between 1 and 60),
 unique(id,workspace_id)
);
create unique index fin_bank_name on public.fin_banks(workspace_id,lower(trim(name)));
create table public.fin_credit_cards (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.fin_workspaces(id) on delete cascade,
 bank_id uuid not null,
 name text not null check(char_length(trim(name)) between 1 and 80),
 unique(id,workspace_id),
 foreign key(bank_id,workspace_id) references public.fin_banks(id,workspace_id) on delete cascade
);
create unique index fin_credit_card_name on public.fin_credit_cards(workspace_id,bank_id,lower(trim(name)));
alter table public.fin_banks enable row level security;
alter table public.fin_credit_cards enable row level security;
revoke all on public.fin_banks,public.fin_credit_cards from public,anon,authenticated;
grant select,insert on public.fin_banks,public.fin_credit_cards to authenticated;
create policy fin_banks_read on public.fin_banks for select to authenticated using(workspace_id in(select workspace_id from public.fin_members where user_id=(select auth.uid())));
create policy fin_banks_insert on public.fin_banks for insert to authenticated with check(workspace_id in(select workspace_id from public.fin_members where user_id=(select auth.uid())));
create policy fin_credit_cards_read on public.fin_credit_cards for select to authenticated using(workspace_id in(select workspace_id from public.fin_members where user_id=(select auth.uid())));
create policy fin_credit_cards_insert on public.fin_credit_cards for insert to authenticated with check(workspace_id in(select workspace_id from public.fin_members where user_id=(select auth.uid())));
alter table public.fin_card_statements add column card_id uuid;
-- Faturas V1 não continham banco: agrupar sem inferir instituição.
insert into public.fin_banks(workspace_id,name) select distinct workspace_id,'Banco não informado (V1)' from public.fin_card_statements;
insert into public.fin_credit_cards(workspace_id,bank_id,name)
 select s.workspace_id,b.id,min(trim(s.card_name)) from public.fin_card_statements s join public.fin_banks b on b.workspace_id=s.workspace_id group by s.workspace_id,b.id,lower(trim(s.card_name));
update public.fin_card_statements s set card_id=c.id from public.fin_credit_cards c where c.workspace_id=s.workspace_id and lower(trim(c.name))=lower(trim(s.card_name));
alter table public.fin_card_statements alter column card_id set not null;
alter table public.fin_card_statements add foreign key(card_id,workspace_id) references public.fin_credit_cards(id,workspace_id);
drop index public.fin_card_statement_cycle;
create unique index fin_card_statement_cycle on public.fin_card_statements(workspace_id,card_id,due_date);
drop function public.fin_save_card_statement(uuid,text,date,bigint,text,jsonb,uuid);
create function public.fin_save_card_statement(p_workspace uuid,p_card_id uuid,p_due date,p_total bigint,p_hash text,p_items jsonb,p_existing uuid default null)
returns table(id uuid) language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_entry uuid; v_category uuid; v_sum numeric; v_count integer; v_card text; v_bank text;
begin
 if v_user is null or not exists(select 1 from public.fin_members m where m.workspace_id=p_workspace and m.user_id=v_user) then raise exception 'Ambiente não autorizado' using errcode='42501'; end if;
 select c.name,b.name into v_card,v_bank from public.fin_credit_cards c join public.fin_banks b on b.id=c.bank_id and b.workspace_id=c.workspace_id where c.id=p_card_id and c.workspace_id=p_workspace;
 if v_card is null or p_due is null or p_total is null or p_total not between 1 and 99999999999 or (p_hash is not null and p_hash !~ '^[0-9a-f]{64}$') then raise exception 'Dados da fatura inválidos'; end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' then raise exception 'Informe os itens'; end if;
 v_count:=jsonb_array_length(p_items); if v_count not between 1 and 2000 then raise exception 'A fatura deve conter de 1 a 2000 itens'; end if;
 select sum(x.amount_cents) into v_sum from jsonb_to_recordset(p_items) as x(purchase_date date,description text,category text,amount_cents bigint);
 if v_sum is distinct from p_total or exists(select 1 from jsonb_to_recordset(p_items) as x(purchase_date date,description text,category text,amount_cents bigint) where x.purchase_date is null or x.purchase_date>p_due or x.description is null or char_length(trim(x.description)) not between 1 and 150 or x.category is null or char_length(trim(x.category)) not between 1 and 60 or x.amount_cents is null or x.amount_cents=0 or x.amount_cents not between -99999999999 and 99999999999) then raise exception 'Itens inválidos ou total divergente'; end if;
 insert into public.fin_categories(workspace_id,kind,name) values(p_workspace,'expense','Cartão de crédito') on conflict(workspace_id,kind,name) do nothing;
 select c.id into strict v_category from public.fin_categories c where c.workspace_id=p_workspace and c.kind='expense' and c.name='Cartão de crédito';
 if p_existing is null then
  insert into public.fin_entries(workspace_id,category_id,kind,description,amount_cents,due_date,status,paid_date,notes,created_by) values(p_workspace,v_category,'expense',left('Fatura • '||v_bank||' / '||v_card,150),p_total,p_due,'pending',null,'Fatura detalhada no módulo Cartões de crédito.',v_user) returning fin_entries.id into v_entry;
 else
  select e.id into v_entry from public.fin_entries e where e.id=p_existing and e.workspace_id=p_workspace and e.kind='expense' and e.amount_cents=p_total and e.due_date=p_due and e.recurring_id is null and not exists(select 1 from public.fin_card_statements s where s.id=e.id) for update;
  if v_entry is null then raise exception 'O lançamento selecionado não corresponde à fatura'; end if;
  update public.fin_entries e set category_id=v_category,description=left('Fatura • '||v_bank||' / '||v_card,150) where e.id=v_entry;
 end if;
 insert into public.fin_card_statements(id,workspace_id,card_id,card_name,due_date,total_cents,source_hash) values(v_entry,p_workspace,p_card_id,v_card,p_due,p_total,p_hash);
 insert into public.fin_card_items(statement_id,workspace_id,purchase_date,description,category,amount_cents) select v_entry,p_workspace,x.purchase_date,trim(x.description),trim(x.category),x.amount_cents from jsonb_to_recordset(p_items) as x(purchase_date date,description text,category text,amount_cents bigint);
 return query select v_entry;
end $$;
revoke all on function public.fin_save_card_statement(uuid,uuid,date,bigint,text,jsonb,uuid) from public,anon,authenticated;
grant execute on function public.fin_save_card_statement(uuid,uuid,date,bigint,text,jsonb,uuid) to authenticated;
commit;

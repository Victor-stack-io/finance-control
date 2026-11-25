-- Migração aditiva. Execute após 04-premium.sql, antes de publicar docs/.
begin;
create table public.fin_card_statements (
 id uuid primary key,
 workspace_id uuid not null references public.fin_workspaces(id) on delete cascade,
 card_name text not null check(char_length(trim(card_name)) between 1 and 80),
 due_date date not null,
 total_cents bigint not null check(total_cents between 1 and 99999999999),
 source_hash text check(source_hash ~ '^[0-9a-f]{64}$'),
 created_at timestamptz not null default now(),
 unique(id,workspace_id),
 foreign key(id) references public.fin_entries(id) on delete cascade
);
create unique index fin_card_statement_cycle on public.fin_card_statements(workspace_id,lower(trim(card_name)),due_date);
create unique index fin_card_statement_file on public.fin_card_statements(workspace_id,source_hash) where source_hash is not null;
create table public.fin_card_items (
 id uuid primary key default gen_random_uuid(),
 statement_id uuid not null,
 workspace_id uuid not null,
 purchase_date date not null,
 description text not null check(char_length(trim(description)) between 1 and 150),
 category text not null check(char_length(trim(category)) between 1 and 60),
 amount_cents bigint not null check(amount_cents between -99999999999 and 99999999999 and amount_cents<>0),
 foreign key(statement_id,workspace_id) references public.fin_card_statements(id,workspace_id) on delete cascade
);
create index fin_card_items_statement_idx on public.fin_card_items(statement_id,workspace_id);
alter table public.fin_card_statements enable row level security;
alter table public.fin_card_items enable row level security;
revoke all on public.fin_card_statements,public.fin_card_items from public,anon,authenticated;
grant select on public.fin_card_statements,public.fin_card_items to authenticated;
create policy fin_card_statements_read on public.fin_card_statements for select to authenticated using(workspace_id in(select workspace_id from public.fin_members where user_id=(select auth.uid())));
create policy fin_card_items_read on public.fin_card_items for select to authenticated using(workspace_id in(select workspace_id from public.fin_members where user_id=(select auth.uid())));
-- Uma fatura e seus itens são gravados em uma única transação; sem escrita direta nas tabelas de detalhes.
create function public.fin_save_card_statement(p_workspace uuid,p_card text,p_due date,p_total bigint,p_hash text,p_items jsonb,p_existing uuid default null)
returns table(id uuid) language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_entry uuid; v_category uuid; v_sum numeric; v_count integer;
begin
 if v_user is null or not exists(select 1 from public.fin_members m where m.workspace_id=p_workspace and m.user_id=v_user) then raise exception 'Ambiente não autorizado' using errcode='42501'; end if;
 if p_card is null or char_length(trim(p_card)) not between 1 and 80 or p_due is null or p_total is null or p_total not between 1 and 99999999999 or (p_hash is not null and p_hash !~ '^[0-9a-f]{64}$') then raise exception 'Dados da fatura inválidos'; end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' then raise exception 'Informe os itens'; end if;
 v_count:=jsonb_array_length(p_items); if v_count not between 1 and 2000 then raise exception 'A fatura deve conter de 1 a 2000 itens'; end if;
 select sum(x.amount_cents) into v_sum from jsonb_to_recordset(p_items) as x(purchase_date date,description text,category text,amount_cents bigint);
 if v_sum is distinct from p_total or exists(select 1 from jsonb_to_recordset(p_items) as x(purchase_date date,description text,category text,amount_cents bigint) where x.purchase_date is null or x.purchase_date>p_due or x.description is null or char_length(trim(x.description)) not between 1 and 150 or x.category is null or char_length(trim(x.category)) not between 1 and 60 or x.amount_cents is null or x.amount_cents=0 or x.amount_cents not between -99999999999 and 99999999999) then raise exception 'Itens inválidos ou total divergente'; end if;
 insert into public.fin_categories(workspace_id,kind,name) values(p_workspace,'expense','Cartão de crédito') on conflict(workspace_id,kind,name) do nothing;
 select c.id into strict v_category from public.fin_categories c where c.workspace_id=p_workspace and c.kind='expense' and c.name='Cartão de crédito';
 if p_existing is null then
  insert into public.fin_entries(workspace_id,category_id,kind,description,amount_cents,due_date,status,paid_date,notes,created_by) values(p_workspace,v_category,'expense','Fatura • '||trim(p_card),p_total,p_due,'pending',null,'Fatura detalhada no módulo Cartões de crédito.',v_user) returning fin_entries.id into v_entry;
 else
  select e.id into v_entry from public.fin_entries e where e.id=p_existing and e.workspace_id=p_workspace and e.kind='expense' and e.amount_cents=p_total and e.due_date=p_due and e.recurring_id is null and not exists(select 1 from public.fin_card_statements s where s.id=e.id) for update;
  if v_entry is null then raise exception 'O lançamento selecionado não corresponde à fatura'; end if;
  update public.fin_entries e set category_id=v_category,description='Fatura • '||trim(p_card) where e.id=v_entry;
 end if;
 insert into public.fin_card_statements(id,workspace_id,card_name,due_date,total_cents,source_hash) values(v_entry,p_workspace,trim(p_card),p_due,p_total,p_hash);
 insert into public.fin_card_items(statement_id,workspace_id,purchase_date,description,category,amount_cents) select v_entry,p_workspace,x.purchase_date,trim(x.description),trim(x.category),x.amount_cents from jsonb_to_recordset(p_items) as x(purchase_date date,description text,category text,amount_cents bigint);
 return query select v_entry;
end $$;
revoke all on function public.fin_save_card_statement(uuid,text,date,bigint,text,jsonb,uuid) from public,anon,authenticated;
grant execute on function public.fin_save_card_statement(uuid,text,date,bigint,text,jsonb,uuid) to authenticated;
-- Preserve a conciliação mesmo se uma versão antiga do frontend tentar alterar o lançamento.
create function public.fin_protect_card_entry() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.fin_card_statements s where s.id=old.id) and (new.workspace_id,new.category_id,new.kind,new.description,new.amount_cents,new.due_date,new.recurring_id,new.recurrence_month) is distinct from (old.workspace_id,old.category_id,old.kind,old.description,old.amount_cents,old.due_date,old.recurring_id,old.recurrence_month) then raise exception 'Fatura vinculada: exclua e reimporte para corrigir valores ou vencimento'; end if;
 return new;
end $$;
revoke all on function public.fin_protect_card_entry() from public,anon,authenticated;
create trigger fin_protect_card_entry before update on public.fin_entries for each row execute function public.fin_protect_card_entry();
commit;

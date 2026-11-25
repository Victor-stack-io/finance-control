-- Execute uma vez no SQL Editor do projeto existente, ANTES de publicar docs/.
-- Migração aditiva: não recria nem exclui dados existentes.
begin;
create table if not exists public.fin_recurring (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.fin_workspaces(id) on delete cascade,
 category_id uuid not null,
 kind text not null check (kind in ('income','expense')),
 description text not null check (char_length(trim(description)) between 1 and 150),
 amount_cents bigint not null check (amount_cents between 1 and 99999999999),
 due_day integer not null check (due_day between 1 and 31),
 start_month date not null check (extract(day from start_month)=1),
 end_month date check (extract(day from end_month)=1),
 unique(id,workspace_id),
 foreign key(category_id,workspace_id,kind) references public.fin_categories(id,workspace_id,kind) on delete restrict
);
alter table public.fin_entries add column if not exists recurring_id uuid;
alter table public.fin_entries add column if not exists recurrence_month date;
alter table public.fin_entries add constraint fin_entry_recurring_pair check ((recurring_id is null and recurrence_month is null) or (recurring_id is not null and recurrence_month is not null and extract(day from recurrence_month)=1));
alter table public.fin_entries add constraint fin_entry_recurring_fk foreign key(recurring_id,workspace_id) references public.fin_recurring(id,workspace_id) on delete restrict;
create unique index fin_entry_recurring_once on public.fin_entries(recurring_id,recurrence_month) where recurring_id is not null;
create table public.fin_budgets (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.fin_workspaces(id) on delete cascade,
 category_id uuid not null, kind text not null default 'expense' check(kind='expense'),
 amount_cents bigint not null check(amount_cents between 1 and 99999999999), unique(workspace_id,category_id),
 foreign key(category_id,workspace_id,kind) references public.fin_categories(id,workspace_id,kind) on delete restrict
);
create table public.fin_goals (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.fin_workspaces(id) on delete cascade,
 name text not null check(char_length(trim(name)) between 1 and 150), target_cents bigint not null check(target_cents between 1 and 99999999999),
 saved_cents bigint not null default 0 check(saved_cents between 0 and 99999999999), target_date date
);
-- Same workspace isolation as existing tables, including family members.
do $$ declare t text; begin
 foreach t in array array['fin_recurring','fin_budgets','fin_goals'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated',t);
 execute format('create policy member_read on public.%I for select to authenticated using (workspace_id in (select workspace_id from public.fin_members where user_id=(select auth.uid())))',t);
 execute format('create policy member_insert on public.%I for insert to authenticated with check (workspace_id in (select workspace_id from public.fin_members where user_id=(select auth.uid())))',t);
 execute format('create policy member_update on public.%I for update to authenticated using (workspace_id in (select workspace_id from public.fin_members where user_id=(select auth.uid()))) with check (workspace_id in (select workspace_id from public.fin_members where user_id=(select auth.uid())))',t);
 execute format('create policy member_delete on public.%I for delete to authenticated using (workspace_id in (select workspace_id from public.fin_members where user_id=(select auth.uid())))',t);
 end loop; end $$;
grant select on public.fin_recurring to authenticated;
grant insert(workspace_id,category_id,kind,description,amount_cents,due_day,start_month,end_month) on public.fin_recurring to authenticated;
grant update(end_month) on public.fin_recurring to authenticated;
grant select,delete on public.fin_budgets,public.fin_goals to authenticated;
grant insert(workspace_id,category_id,amount_cents) on public.fin_budgets to authenticated;
grant update(amount_cents) on public.fin_budgets to authenticated;
grant insert(workspace_id,name,target_cents,saved_cents,target_date) on public.fin_goals to authenticated;
grant update(name,target_cents,saved_cents,target_date) on public.fin_goals to authenticated;
grant insert(recurring_id,recurrence_month) on public.fin_entries to authenticated;
-- Edição de recorrência cria nova versão prospectiva de forma atômica.
create function public.fin_replace_recurring(p_workspace uuid,p_id uuid,p_cutoff date,p_category uuid,p_kind text,p_description text,p_amount bigint,p_day integer,p_end date)
returns uuid language plpgsql security invoker set search_path = '' as $$
declare oldrow public.fin_recurring%rowtype; new_id uuid;
begin
 if extract(day from p_cutoff)<>1 or p_cutoff < (date_trunc('month',now() at time zone 'America/Sao_Paulo') + interval '1 month')::date then raise exception 'A alteração começa no próximo mês ou depois'; end if;
 select * into strict oldrow from public.fin_recurring where id=p_id and workspace_id=p_workspace for update;
 if oldrow.end_month is not null and oldrow.end_month < p_cutoff then raise exception 'Recorrência já encerrada antes da alteração'; end if;
 if p_cutoff < oldrow.start_month or (p_end is not null and p_end < p_cutoff) then raise exception 'Período inválido'; end if;
 update public.fin_recurring set end_month=(p_cutoff - interval '1 month')::date where id=p_id and workspace_id=p_workspace;
 -- Already materialized future occurrences must not duplicate under the new rule.
 if exists(select 1 from public.fin_entries where recurring_id=p_id and recurrence_month>=p_cutoff) then raise exception 'Existem lançamentos futuros vinculados. Resolva-os antes de alterar a recorrência.'; end if;
 insert into public.fin_recurring(workspace_id,category_id,kind,description,amount_cents,due_day,start_month,end_month) values(p_workspace,p_category,p_kind,p_description,p_amount,p_day,p_cutoff,p_end) returning id into new_id;
 return new_id;
end $$;
revoke all on function public.fin_replace_recurring(uuid,uuid,date,uuid,text,text,bigint,integer,date) from public,anon;
grant execute on function public.fin_replace_recurring(uuid,uuid,date,uuid,text,text,bigint,integer,date) to authenticated;
alter table public.fin_entries add constraint fin_entry_recurring_due_month check (recurrence_month is null or (extract(year from due_date)=extract(year from recurrence_month) and extract(month from due_date)=extract(month from recurrence_month)));
create function public.fin_validate_recurring_entry() returns trigger language plpgsql security invoker set search_path = '' as $$
declare r public.fin_recurring%rowtype;
begin
 if new.recurring_id is null then return new; end if;
 select * into strict r from public.fin_recurring where id=new.recurring_id and workspace_id=new.workspace_id for share;
 if new.recurrence_month < r.start_month or (r.end_month is not null and new.recurrence_month > r.end_month) then raise exception 'Recorrência encerrada ou fora do período'; end if;
 return new;
end $$;
revoke all on function public.fin_validate_recurring_entry() from public,anon;
grant execute on function public.fin_validate_recurring_entry() to authenticated;
create trigger fin_validate_recurring_entry before insert on public.fin_entries for each row execute function public.fin_validate_recurring_entry();
commit;

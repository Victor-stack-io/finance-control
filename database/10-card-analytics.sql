-- V4: execute após 08. Categorias, regras e limites exclusivos dos cartões.
begin;
create table public.fin_card_categories (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.fin_workspaces(id) on delete cascade,
 name text not null check(char_length(trim(name)) between 1 and 60), unique(workspace_id,name)
);
create table public.fin_card_rules (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.fin_workspaces(id) on delete cascade,
 merchant_key text not null check(char_length(merchant_key) between 1 and 150), category text not null check(char_length(trim(category)) between 1 and 60), unique(workspace_id,merchant_key)
);
create table public.fin_card_limits (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.fin_workspaces(id) on delete cascade,
 category text not null check(char_length(trim(category)) between 1 and 60), amount_cents bigint not null check(amount_cents between 1 and 99999999999), unique(workspace_id,category)
);
do $$ declare t text; begin
 foreach t in array array['fin_card_categories','fin_card_rules','fin_card_limits'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated',t);
 execute format('grant select,insert,update,delete on public.%I to authenticated',t);
 execute format('create policy members_only on public.%I for all to authenticated using (workspace_id in (select workspace_id from public.fin_members where user_id=(select auth.uid()))) with check (workspace_id in (select workspace_id from public.fin_members where user_id=(select auth.uid())))',t);
 end loop;
end $$;
create function public.fin_reclassify_card_item(p_workspace uuid,p_item uuid,p_category text,p_merchant_key text default null)
returns table(id uuid) language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.fin_members m where m.workspace_id=p_workspace and m.user_id=auth.uid()) then raise exception 'Ambiente não autorizado' using errcode='42501'; end if;
 if p_category is null or char_length(trim(p_category)) not between 1 and 60 then raise exception 'Categoria inválida'; end if;
 update public.fin_card_items i set category=trim(p_category) where i.id=p_item and i.workspace_id=p_workspace;
 if not found then raise exception 'Compra não localizada'; end if;
 if p_merchant_key is not null then
 insert into public.fin_card_rules(workspace_id,merchant_key,category) values(p_workspace,p_merchant_key,trim(p_category)) on conflict(workspace_id,merchant_key) do update set category=excluded.category;
 end if;
 return query select p_item;
end $$;
revoke all on function public.fin_reclassify_card_item(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.fin_reclassify_card_item(uuid,uuid,text,text) to authenticated;
-- Grava regras explicitamente escolhidas na revisão, junto da fatura (transação única).
create function public.fin_save_card_statement_v4(p_workspace uuid,p_card_id uuid,p_due date,p_total bigint,p_hash text,p_items jsonb,p_existing uuid,p_rules jsonb)
returns table(id uuid) language plpgsql security invoker set search_path='' as $$
declare v_id uuid; r record;
begin
 select s.id into strict v_id from public.fin_save_card_statement(p_workspace,p_card_id,p_due,p_total,p_hash,p_items,p_existing) s;
 if p_rules is null or jsonb_typeof(p_rules)<>'array' or jsonb_array_length(p_rules)>2000 then raise exception 'Regras inválidas'; end if;
 for r in select * from jsonb_to_recordset(p_rules) as x(merchant_key text,category text) loop
 insert into public.fin_card_rules(workspace_id,merchant_key,category) values(p_workspace,r.merchant_key,r.category) on conflict(workspace_id,merchant_key) do update set category=excluded.category;
 end loop;
 return query select v_id;
end $$;
revoke all on function public.fin_save_card_statement_v4(uuid,uuid,date,bigint,text,jsonb,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.fin_save_card_statement_v4(uuid,uuid,date,bigint,text,jsonb,uuid,jsonb) to authenticated;
commit;

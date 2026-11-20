-- Executar uma vez em um projeto Supabase novo, no SQL Editor.
begin;
create table public.fin_workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 80),
  kind text not null check (kind in ('personal','family')),
  slug text not null unique
);
create table public.fin_members (
  workspace_id uuid not null references public.fin_workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  primary key (workspace_id,user_id)
);
create index fin_members_user_idx on public.fin_members(user_id,workspace_id);
create table public.fin_categories (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.fin_workspaces(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 60),
  kind text not null check (kind in ('income','expense')),
  unique (workspace_id,kind,name),
  unique (id,workspace_id,kind)
);
create table public.fin_entries (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.fin_workspaces(id) on delete cascade,
  category_id uuid not null,
  kind text not null check (kind in ('income','expense')),
  description text not null check (char_length(trim(description)) between 1 and 150),
  amount_cents bigint not null check (amount_cents between 1 and 99999999999),
  due_date date not null,
  status text not null check (status in ('pending','paid')),
  paid_date date,
  notes text not null default '' check (char_length(notes) <= 500),
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint fin_entries_paid_date_check check (
    (status='pending' and paid_date is null) or (status='paid' and paid_date is not null)
  ),
  constraint fin_entries_category_fk foreign key (category_id,workspace_id,kind)
    references public.fin_categories(id,workspace_id,kind) on delete restrict
);
create index fin_entries_month_idx on public.fin_entries(workspace_id,due_date,id);
create index fin_entries_category_idx on public.fin_entries(category_id);

alter table public.fin_workspaces enable row level security;
alter table public.fin_members enable row level security;
alter table public.fin_categories enable row level security;
alter table public.fin_entries enable row level security;
revoke all on public.fin_workspaces,public.fin_members,public.fin_categories,public.fin_entries from public,anon,authenticated;
grant select on public.fin_workspaces,public.fin_members to authenticated;
grant select,delete on public.fin_categories,public.fin_entries to authenticated;
grant insert (workspace_id,name,kind) on public.fin_categories to authenticated;
grant update (name) on public.fin_categories to authenticated;
grant insert (workspace_id,category_id,kind,description,amount_cents,due_date,status,paid_date,notes) on public.fin_entries to authenticated;
grant update (category_id,kind,description,amount_cents,due_date,status,paid_date,notes) on public.fin_entries to authenticated;

-- Não há permissão de escrita para ambientes nem membros via navegador.
create policy fin_members_read on public.fin_members for select to authenticated
  using (user_id=(select auth.uid()));
create policy fin_workspaces_read on public.fin_workspaces for select to authenticated
  using (id in (select workspace_id from public.fin_members where user_id=(select auth.uid())));

create policy fin_categories_read on public.fin_categories for select to authenticated
  using (workspace_id in (select workspace_id from public.fin_members where user_id=(select auth.uid())));
create policy fin_categories_insert on public.fin_categories for insert to authenticated
  with check (workspace_id in (select workspace_id from public.fin_members where user_id=(select auth.uid())));
create policy fin_categories_update on public.fin_categories for update to authenticated
  using (workspace_id in (select workspace_id from public.fin_members where user_id=(select auth.uid())))
  with check (workspace_id in (select workspace_id from public.fin_members where user_id=(select auth.uid())));
create policy fin_categories_delete on public.fin_categories for delete to authenticated
  using (workspace_id in (select workspace_id from public.fin_members where user_id=(select auth.uid())));

create policy fin_entries_read on public.fin_entries for select to authenticated
  using (workspace_id in (select workspace_id from public.fin_members where user_id=(select auth.uid())));
create policy fin_entries_insert on public.fin_entries for insert to authenticated
  with check (created_by=(select auth.uid()) and workspace_id in (select workspace_id from public.fin_members where user_id=(select auth.uid())));
create policy fin_entries_update on public.fin_entries for update to authenticated
  using (workspace_id in (select workspace_id from public.fin_members where user_id=(select auth.uid())))
  with check (workspace_id in (select workspace_id from public.fin_members where user_id=(select auth.uid())));
create policy fin_entries_delete on public.fin_entries for delete to authenticated
  using (workspace_id in (select workspace_id from public.fin_members where user_id=(select auth.uid())));
commit;

-- Rodar após 01 e 02. Não deixa lançamentos: tudo é revertido.
-- Simula os dois JWTs no SQL Editor. Não substitui testes reais pelo navegador.
begin;
select set_config('fin.test_a',(select m.user_id::text from public.fin_members m join public.fin_workspaces w on w.id=m.workspace_id where w.slug='pessoal-a'),true);
select set_config('fin.test_b',(select m.user_id::text from public.fin_members m join public.fin_workspaces w on w.id=m.workspace_id where w.slug='pessoal-b'),true);
select set_config('fin.test_wa',(select id::text from public.fin_workspaces where slug='pessoal-a'),true);
select set_config('fin.test_wb',(select id::text from public.fin_workspaces where slug='pessoal-b'),true);
select set_config('fin.test_wf',(select id::text from public.fin_workspaces where slug='familiar'),true);
select set_config('fin.test_cb',(select id::text from public.fin_categories where workspace_id=current_setting('fin.test_wb')::uuid and kind='expense' limit 1),true);
set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('fin.test_a'),true);
do $$
declare cid uuid; fid uuid;
begin
  if (select count(*) from public.fin_workspaces)<>2 then raise exception 'Falha: A deveria ver 2 ambientes'; end if;
  if exists(select 1 from public.fin_workspaces where id=current_setting('fin.test_wb')::uuid) then raise exception 'Falha: A vê ambiente B'; end if;
  if exists(select 1 from public.fin_categories where workspace_id=current_setting('fin.test_wb')::uuid) then raise exception 'Falha: A vê categorias B'; end if;
  select id into cid from public.fin_categories where workspace_id=current_setting('fin.test_wa')::uuid and kind='expense' limit 1;
  insert into public.fin_entries(workspace_id,category_id,kind,description,amount_cents,due_date,status) values (current_setting('fin.test_wa')::uuid,cid,'expense','TESTE RLS A',100,current_date,'pending');
  select id into fid from public.fin_categories where workspace_id=current_setting('fin.test_wf')::uuid and kind='expense' limit 1;
  insert into public.fin_entries(workspace_id,category_id,kind,description,amount_cents,due_date,status) values (current_setting('fin.test_wf')::uuid,fid,'expense','TESTE RLS FAMILIA',100,current_date,'pending');
  begin
    insert into public.fin_entries(workspace_id,category_id,kind,description,amount_cents,due_date,status) values (current_setting('fin.test_wb')::uuid,current_setting('fin.test_cb')::uuid,'expense','TESTE RLS INDEVIDO',100,current_date,'pending');
    raise exception 'Falha: A inseriu no ambiente B';
  exception when insufficient_privilege then null;
  end;
end $$;
select set_config('request.jwt.claim.sub',current_setting('fin.test_b'),true);
do $$
declare affected int;
begin
  if (select count(*) from public.fin_workspaces)<>2 then raise exception 'Falha: B deveria ver 2 ambientes'; end if;
  if exists(select 1 from public.fin_entries where workspace_id=current_setting('fin.test_wa')::uuid) then raise exception 'Falha: B vê lançamentos A'; end if;
  if not exists(select 1 from public.fin_entries where workspace_id=current_setting('fin.test_wf')::uuid and description='TESTE RLS FAMILIA') then raise exception 'Falha: B não vê familiar'; end if;
  update public.fin_entries set description='TESTE ALTERADO' where workspace_id=current_setting('fin.test_wa')::uuid;
  get diagnostics affected=row_count;
  if affected<>0 then raise exception 'Falha: B alterou dados A'; end if;
  update public.fin_entries set status='paid',paid_date=current_date where workspace_id=current_setting('fin.test_wf')::uuid and description='TESTE RLS FAMILIA';
  if not found then raise exception 'Falha: B não conseguiu editar familiar'; end if;
end $$;
reset role;
rollback;
-- Se o script finalizar sem exceção, as verificações acima passaram.

-- Opcional: teste transacional após 04-premium.sql, no banco provisionado original.
-- Nenhum registro de teste é mantido. Usa os ambientes criados pelo 02-provision.sql.
begin;
select set_config('fin.test_a',(select m.user_id::text from public.fin_members m join public.fin_workspaces w on w.id=m.workspace_id where w.slug='pessoal-a'),true);
select set_config('fin.test_b',(select m.user_id::text from public.fin_members m join public.fin_workspaces w on w.id=m.workspace_id where w.slug='pessoal-b'),true);
select set_config('fin.test_wa',(select id::text from public.fin_workspaces where slug='pessoal-a'),true);
select set_config('fin.test_wb',(select id::text from public.fin_workspaces where slug='pessoal-b'),true);
select set_config('fin.test_wf',(select id::text from public.fin_workspaces where slug='familiar'),true);
set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('fin.test_a'),true);
do $$
declare wa uuid:=current_setting('fin.test_wa')::uuid; wf uuid:=current_setting('fin.test_wf')::uuid; wb uuid:=current_setting('fin.test_wb')::uuid; ca uuid; cf uuid; r uuid; m date:=date_trunc('month',current_date)::date; g uuid;
begin
 insert into public.fin_categories(workspace_id,name,kind) values(wa,'__TESTE_PREMIUM_'||gen_random_uuid()::text,'expense') returning id into ca;
 insert into public.fin_categories(workspace_id,name,kind) values(wf,'__TESTE_PREMIUM_'||gen_random_uuid()::text,'expense') returning id into cf;
 insert into public.fin_recurring(workspace_id,category_id,kind,description,amount_cents,due_day,start_month) values(wa,ca,'expense','TESTE PREMIUM',15000,31,m) returning id into r;
 insert into public.fin_entries(workspace_id,category_id,kind,description,amount_cents,due_date,status,recurring_id,recurrence_month) values(wa,ca,'expense','TESTE PREMIUM',15000,m,'pending',r,m);
 begin
  insert into public.fin_entries(workspace_id,category_id,kind,description,amount_cents,due_date,status,recurring_id,recurrence_month) values(wa,ca,'expense','TESTE DUPLICADO',15000,m,'pending',r,m);
  raise exception 'Falha: ocorrência duplicada permitida';
 exception when unique_violation then null; end;
 insert into public.fin_budgets(workspace_id,category_id,amount_cents) values(wa,ca,50000);
 insert into public.fin_budgets(workspace_id,category_id,amount_cents) values(wf,cf,50000);
 insert into public.fin_goals(workspace_id,name,target_cents) values(wa,'TESTE PREMIUM',100000) returning id into g;
 perform set_config('fin.test_goal',g::text,true);
 insert into public.fin_goals(workspace_id,name,target_cents) values(wf,'TESTE PREMIUM FAMILIAR',100000) returning id into g;
 perform set_config('fin.test_goal_family',g::text,true);
 begin
  insert into public.fin_goals(workspace_id,name,target_cents) values(wb,'TESTE INDEVIDO',100000);
  raise exception 'Falha: escrita em ambiente de outro usuário';
 exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub',current_setting('fin.test_b'),true);
do $$
declare wa uuid:=current_setting('fin.test_wa')::uuid;
begin
 if exists(select 1 from public.fin_recurring where workspace_id=wa) or exists(select 1 from public.fin_budgets where workspace_id=wa) or exists(select 1 from public.fin_goals where workspace_id=wa) then raise exception 'Falha: B vê dados pessoais de A'; end if;
 update public.fin_goals set saved_cents=500 where id=current_setting('fin.test_goal')::uuid;
 if found then raise exception 'Falha: B altera meta de A'; end if;
 update public.fin_goals set saved_cents=500 where id=current_setting('fin.test_goal_family')::uuid;
 if not found then raise exception 'Falha: B não acessa a meta familiar'; end if;
end $$;
reset role;
rollback;

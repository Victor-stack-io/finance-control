-- Teste transacional após 11; pressupõe provisionamento pessoal-a/pessoal-b. ROLLBACK final.
begin;
select set_config('fin.test_a',(select m.user_id::text from public.fin_members m join public.fin_workspaces w on w.id=m.workspace_id where w.slug='pessoal-a'),true);
select set_config('fin.test_b',(select m.user_id::text from public.fin_members m join public.fin_workspaces w on w.id=m.workspace_id where w.slug='pessoal-b'),true);
select set_config('fin.test_wa',(select id::text from public.fin_workspaces where slug='pessoal-a'),true);
select set_config('fin.test_wb',(select id::text from public.fin_workspaces where slug='pessoal-b'),true);
set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('fin.test_a'),true);
do $$
declare wa uuid:=current_setting('fin.test_wa')::uuid; wb uuid:=current_setting('fin.test_wb')::uuid; b uuid; c uuid; s uuid; d date:=current_date; items jsonb; h text:=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');
begin
 insert into public.fin_banks(workspace_id,name) values(wa,'Teste V6 '||gen_random_uuid()) returning id into b;
 insert into public.fin_credit_cards(workspace_id,bank_id,name) values(wa,b,'Teste V6') returning id into c;
 items:=jsonb_build_array(jsonb_build_object('purchase_date',d,'description','Compra teste','category','Outros','amount_cents',3450,'movement_type','purchase','card_last4','1234'),jsonb_build_object('purchase_date',d,'description','Pagamento teste','category','Pagamentos de fatura','amount_cents',-6000,'movement_type','payment'));
 select id into strict s from public.fin_save_card_statement_v6(wa,c,d,2450,h,items,null,5000,'[]');
 if not exists(select 1 from public.fin_card_statements where id=s and previous_balance_cents=5000 and total_cents=2450) then raise exception 'Fatura não conciliada'; end if;
 if (select sum(amount_cents) from public.fin_card_items where statement_id=s and movement_type<>'payment') is distinct from 3450::numeric then raise exception 'Gastos incorretos'; end if;
 if (select amount_cents from public.fin_entries where id=s) is distinct from 2450::bigint then raise exception 'Despesa incorreta'; end if;
 begin perform public.fin_save_card_statement_v6(wa,c,d+1,2451,null,items,null,5000,'[]'); raise exception 'Teste: aceitou divergência' using errcode='XX000'; exception when raise_exception then null; end;
 begin perform public.fin_save_card_statement_v6(wa,c,d,2450,null,items,null,5000,'[]'); raise exception 'Teste: duplicidade aceita'; exception when unique_violation then null; end;
 begin perform public.fin_save_card_statement_v6(wa,c,d+1,2450,h,items,null,5000,'[]'); raise exception 'Teste: hash duplicado aceito'; exception when unique_violation then null; end;
 begin perform public.fin_save_card_statement_v6(wb,c,d,2450,null,items,null,5000,'[]'); raise exception 'Teste: acesso cruzado aceito'; exception when insufficient_privilege then null; end;
 perform set_config('fin.test_statement',s::text,true);
end $$;
select set_config('request.jwt.claim.sub',current_setting('fin.test_b'),true);
do $$ begin
 if exists(select 1 from public.fin_card_statements where id=current_setting('fin.test_statement')::uuid) or exists(select 1 from public.fin_card_items where statement_id=current_setting('fin.test_statement')::uuid) then raise exception 'RLS: acesso cruzado'; end if;
end $$;
reset role;
rollback;

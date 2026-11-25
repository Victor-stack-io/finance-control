-- Teste após 06, em ambiente de homologação provisionado. Nenhum dado fica gravado.
begin;
select set_config('fin.test_a',(select m.user_id::text from public.fin_members m join public.fin_workspaces w on w.id=m.workspace_id where w.slug='pessoal-a'),true);
select set_config('fin.test_b',(select m.user_id::text from public.fin_members m join public.fin_workspaces w on w.id=m.workspace_id where w.slug='pessoal-b'),true);
select set_config('fin.test_wa',(select id::text from public.fin_workspaces where slug='pessoal-a'),true);
select set_config('fin.test_wb',(select id::text from public.fin_workspaces where slug='pessoal-b'),true);
set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('fin.test_a'),true);
do $$
declare wa uuid:=current_setting('fin.test_wa')::uuid; wb uuid:=current_setting('fin.test_wb')::uuid; v_id uuid; v_existing uuid; v_cat uuid; d date:=current_date; n text:='Teste-'||gen_random_uuid()::text; items jsonb; h text:=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');
begin
 items:=jsonb_build_array(jsonb_build_object('purchase_date',d,'description','Uber','category','Transporte','amount_cents',15000),jsonb_build_object('purchase_date',d,'description','Estorno','category','Crédito','amount_cents',-2000));
 select s.id into v_id from public.fin_save_card_statement(wa,n,d,13000,h,items) s;
 if (select count(*) from public.fin_entries where id=v_id and amount_cents=13000 and status='pending')<>1 or (select sum(amount_cents) from public.fin_card_items where statement_id=v_id)<>13000 then raise exception 'Fatura inconsistente'; end if;
 begin perform public.fin_save_card_statement(wa,n,d,13000,null,items); raise exception 'Duplicidade permitida'; exception when unique_violation then null; end;
 begin perform public.fin_save_card_statement(wa,n||'-2',d,13000,h,items); raise exception 'Arquivo duplicado permitido'; exception when unique_violation then null; end;
 begin perform public.fin_save_card_statement(wb,n,d,13000,null,items); raise exception 'Acesso indevido permitido'; exception when insufficient_privilege then null; end;
 begin perform public.fin_save_card_statement(wa,n||'-3',d,13001,null,items); raise exception 'Total divergente permitido'; exception when raise_exception then if sqlerrm<>'Itens inválidos ou total divergente' then raise; end if; end;
 begin update public.fin_entries set amount_cents=1 where id=v_id; raise exception 'Alteração indevida permitida'; exception when raise_exception then if sqlerrm not like 'Fatura vinculada:%' then raise; end if; end;
 update public.fin_entries set status='paid',paid_date=d where id=v_id;
 if not exists(select 1 from public.fin_entries where id=v_id and status='paid') then raise exception 'Pagamento não gravado'; end if;
 insert into public.fin_categories(workspace_id,name,kind) values(wa,n,'expense') returning id into v_cat;
 insert into public.fin_entries(workspace_id,category_id,kind,description,amount_cents,due_date,status) values(wa,v_cat,'expense',n,13000,d,'pending') returning id into v_existing;
 perform public.fin_save_card_statement(wa,n||'-4',d,13000,null,items,v_existing);
 if not exists(select 1 from public.fin_card_statements where id=v_existing) then raise exception 'Lançamento anterior não vinculado'; end if;
 delete from public.fin_entries where id=v_existing;
 if exists(select 1 from public.fin_card_statements where id=v_existing) or exists(select 1 from public.fin_card_items where statement_id=v_existing) then raise exception 'Exclusão inconsistente'; end if;
 perform set_config('fin.test_card',v_id::text,true);
end $$;
select set_config('request.jwt.claim.sub',current_setting('fin.test_b'),true);
do $$ begin
 if exists(select 1 from public.fin_card_statements where id=current_setting('fin.test_card')::uuid) or exists(select 1 from public.fin_card_items where statement_id=current_setting('fin.test_card')::uuid) then raise exception 'RLS: B visualiza fatura pessoal de A'; end if;
end $$;
reset role;
rollback;

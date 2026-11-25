-- Homologação após 08; pressupõe provisionamento pessoal-a/pessoal-b. ROLLBACK final.
begin;
select set_config('fin.test_a',(select m.user_id::text from public.fin_members m join public.fin_workspaces w on w.id=m.workspace_id where w.slug='pessoal-a'),true);
select set_config('fin.test_b',(select m.user_id::text from public.fin_members m join public.fin_workspaces w on w.id=m.workspace_id where w.slug='pessoal-b'),true);
select set_config('fin.test_wa',(select id::text from public.fin_workspaces where slug='pessoal-a'),true);
select set_config('fin.test_wb',(select id::text from public.fin_workspaces where slug='pessoal-b'),true);
set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('fin.test_a'),true);
do $$
declare wa uuid:=current_setting('fin.test_wa')::uuid; wb uuid:=current_setting('fin.test_wb')::uuid; b1 uuid; b2 uuid; c1 uuid; c2 uuid; c3 uuid; s1 uuid; s2 uuid; s3 uuid; d date:=current_date; n text:='Teste-'||gen_random_uuid()::text; items jsonb;
begin
 insert into public.fin_banks(workspace_id,name) values(wa,n) returning id into b1;
 insert into public.fin_banks(workspace_id,name) values(wa,n||'-2') returning id into b2;
 insert into public.fin_credit_cards(workspace_id,bank_id,name) values(wa,b1,'Pessoal') returning id into c1;
 insert into public.fin_credit_cards(workspace_id,bank_id,name) values(wa,b1,'Virtual') returning id into c2;
 insert into public.fin_credit_cards(workspace_id,bank_id,name) values(wa,b2,'Pessoal') returning id into c3;
 items:=jsonb_build_array(jsonb_build_object('purchase_date',d,'description','Teste','category','Outros','amount_cents',10000));
 select id into s1 from public.fin_save_card_statement(wa,c1,d,10000,null,items);
 select id into s2 from public.fin_save_card_statement(wa,c2,d,10000,null,items);
 select id into s3 from public.fin_save_card_statement(wa,c3,d,10000,null,items);
 if (select sum(amount_cents) from public.fin_entries where id in(s1,s2,s3))<>30000 then raise exception 'Saldo divergente'; end if;
 if (select sum(s.total_cents) from public.fin_card_statements s join public.fin_credit_cards c on c.id=s.card_id where c.bank_id=b1)<>20000 then raise exception 'Consolidação por banco divergente'; end if;
 begin perform public.fin_save_card_statement(wa,c1,d,10000,null,items); raise exception 'Duplicidade permitida'; exception when unique_violation then null; end;
 begin insert into public.fin_banks(workspace_id,name) values(wb,n); raise exception 'Cadastro entre ambientes permitido'; exception when insufficient_privilege then null; end;
 update public.fin_entries set status='paid',paid_date=d where id=s1;
 if not exists(select 1 from public.fin_entries where id=s1 and status='paid') then raise exception 'Pagamento não gravado'; end if;
 perform set_config('fin.test_bank',b1::text,true); perform set_config('fin.test_cc',c1::text,true); perform set_config('fin.test_statement',s1::text,true);
end $$;
select set_config('request.jwt.claim.sub',current_setting('fin.test_b'),true);
do $$
begin
 if exists(select 1 from public.fin_banks where id=current_setting('fin.test_bank')::uuid) or exists(select 1 from public.fin_credit_cards where id=current_setting('fin.test_cc')::uuid) or exists(select 1 from public.fin_card_statements where id=current_setting('fin.test_statement')::uuid) then raise exception 'RLS: acesso a dados de outro ambiente'; end if;
 begin insert into public.fin_credit_cards(workspace_id,bank_id,name) values(current_setting('fin.test_wb')::uuid,current_setting('fin.test_bank')::uuid,'Intruso'); raise exception 'Vínculo cruzado permitido'; exception when foreign_key_violation then null; end;
end $$;
reset role;
rollback;

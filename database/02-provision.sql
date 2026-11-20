-- Execute no SQL Editor APÓS criar os dois usuários em Authentication > Users.
-- Troque os dois e-mails SOMENTE no SQL Editor. Não publique os e-mails reais.
-- Script de instalação única; não é um mecanismo de alteração de membros.
begin;
do $$
declare
  email_a text := 'victorkuroasaki@hotmail.com';
  email_b text := 'ana.erdman2021@gmail.com';
  a uuid; b uuid; wa uuid; wb uuid; wf uuid;
begin
  select id into a from auth.users where lower(email)=lower(email_a);
  select id into b from auth.users where lower(email)=lower(email_b);
  if a is null or b is null or a=b then
    raise exception 'Crie dois usuários distintos e confira os e-mails.';
  end if;
  insert into public.fin_workspaces(name,kind,slug) values ('Meu financeiro','personal','pessoal-a') returning id into wa;
  insert into public.fin_workspaces(name,kind,slug) values ('Meu financeiro','personal','pessoal-b') returning id into wb;
  insert into public.fin_workspaces(name,kind,slug) values ('Financeiro familiar','family','familiar') returning id into wf;
  insert into public.fin_members(workspace_id,user_id) values (wa,a),(wb,b),(wf,a),(wf,b);
  insert into public.fin_categories(workspace_id,name,kind)
  select w.id,c.name,c.kind from public.fin_workspaces w
  cross join (values ('Salário','income'),('Renda extra','income'),('Outras receitas','income'),
    ('Moradia','expense'),('Alimentação','expense'),('Transporte','expense'),('Saúde','expense'),
    ('Educação','expense'),('Lazer','expense'),('Serviços','expense'),('Outras despesas','expense')) c(name,kind)
  where w.id in (wa,wb,wf);
end $$;
commit;

# Finance Control

Controle financeiro pessoal e familiar, com HTML/CSS/JS, Supabase e GitHub Pages. Aplicativo PWA online. Cada pessoa tem um login e acesso ao próprio ambiente e ao familiar.

## Configuração
1. Crie um projeto Supabase e rode `database/01-schema.sql` no SQL Editor.
2. Crie dois usuários em Authentication > Users e execute `database/02-provision.sql` com os e-mails reais **apenas no SQL Editor**.
3. Execute `database/03-test-rls.sql` para verificar isolamento.
4. Configure `docs/config.js` com URL e chave publicável do projeto (nunca uma chave secreta).
5. Publique `main` / `docs` pelo GitHub Pages e configure a URL de retorno em Supabase Auth.

## Desenvolvimento local
Abra `docs/index.html` com Live Server no VS Code. Não use `file://` para teste de instalação PWA. Configure a URL local em Supabase Authentication > URL Configuration se for testar recuperação de senha.

## Segurança
Não versionar dados financeiros, senhas, chaves secretas, dumps ou e-mails reais. O acesso é autorizado pelo banco (RLS). GitHub Pages publica apenas `docs/`. O navegador guarda a sessão de login; use Sair ao compartilhar o computador. Exige internet; não guarda registros financeiros em cache de service worker.

## Escopo
Lançamentos manuais, receitas e despesas, categorias, realizado/pendente, vencimentos, dashboard por mês de vencimento e exportação CSV. A versão premium acrescenta recorrências, orçamentos e metas. O módulo Cartões de crédito acrescenta importação CSV/PDF, revisão e conciliação do total de faturas, com uma despesa por fatura. Consulte `CARTOES_DE_CREDITO.md` e execute a migração `database/06-credit-cards.sql` após `04-premium.sql`. Contas bancárias, parcelamentos automáticos e saldo acumulado ficam para versões posteriores.

## Cartões de crédito V2
Consulte [BANCOS_E_CARTOES_V2.md](BANCOS_E_CARTOES_V2.md) para cadastro de bancos, cartões e migrações.

## V5 — Importação bancária ampliada
Consulte [V5_IMPORTACAO_UNIVERSAL.md](V5_IMPORTACAO_UNIVERSAL.md) para instalação, compatibilidade e pendências de homologação.

## V6 — Importação e conciliação de faturas
Consulte [V6_IMPORTACAO_CONCILIACAO.md](V6_IMPORTACAO_CONCILIACAO.md). Aplique a migração 11 antes de publicar a nova versão.

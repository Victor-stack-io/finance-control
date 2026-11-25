# Finance Control — Bancos e cartões V2

Atualização sobre V1. Arquitetura preservada: HTML/CSS/JS + Supabase + GitHub Pages.

## Implantação em homologação
- Se ainda não instalou V1, execute 06-credit-cards.sql, depois 07-test-credit-cards.sql (teste V1 opcional em homologação), e então 08-banks-and-cards.sql.
- Se já instalou V1, execute somente 08-banks-and-cards.sql. Faça backup antes.
- Execute 09-test-banks-and-cards.sql para validar a V2. O teste 07 é específico da V1 e não deve ser executado após 08. O teste 09 exige os ambientes pessoais do provisionamento original.
- Publique docs/ completo somente após homologação das migrações. O RPC da V2 substitui o da V1, portanto sincronize banco e frontend e atualize o navegador/PWA.

## Uso
Em Cartões de crédito > Cadastro de bancos e cartões, cadastre o banco e um ou mais cartões (apelidos distintos dentro do banco). Escolha banco e cartão ao importar. O consolidado usa o vencimento e inclui faturas pagas e pendentes; o filtro de banco altera apenas o detalhamento, não o total global. O painel inicial também exibe total e valor a pagar, já incluídos nas despesas gerais.

Cada fatura cria uma despesa única, identificada por banco/cartão. O detalhe por categoria não gera lançamentos adicionais. Uma fatura por cartão/vencimento e a mesma impressão digital de arquivo por ambiente são bloqueadas contra duplicidade. Não são necessárias credenciais bancárias nem número do cartão.

CSV: informe o vencimento e o total oficial a pagar e revise os itens. Pagamentos anteriores são excluídos do cálculo de compras, estornos são mantidos como negativos. Se um pagamento se referir à fatura atual, confirme o saldo devido e o tratamento contábil antes de registrar; esta versão não possui pagamento parcial nem conciliação automática de saldo anterior. Um CSV não comprova o total oficial devido. PDF segue os limites da V1, sem OCR e com revisão obrigatória.

Faturas legadas recebem vínculo com o banco 'Banco não informado (V1)' e cartões agrupados pelo nome anterior; nenhum valor ou status é alterado. A V2 disponibiliza cadastro e consulta, mas não edição, exclusão ou transferência de bancos/cartões pela interface. Reclassificação do legado requer migração administrativa revisada. Não inclua arquivos reais de faturas no repositório.

## Validação
`node tests/card-parser.test.cjs`, `node tests/banks.test.cjs`, `node --check` nos JS/MJS. Testes SQL preparados, mas não executados em banco real neste ambiente. Interface e PDF ainda exigem homologação no navegador.

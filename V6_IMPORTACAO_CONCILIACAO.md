# Finance Control V6 — Importação e conciliação de faturas

## Atualização de instalação existente

1. Faça backup do projeto e do banco Supabase.
2. No Supabase SQL Editor, execute `database/11-card-reconciliation.sql` **após** as migrações anteriores, inclusive `10-card-analytics.sql`. É aditiva: não exclui faturas e mantém as RPCs antigas. Em caso de erro, não prossiga para publicação.
3. Se o ambiente possuir os workspaces de teste `pessoal-a` e `pessoal-b`, execute `database/12-test-card-reconciliation.sql` (transação com ROLLBACK). Confere conciliação, duplicidade e RLS.
4. Substitua o código do repositório pelo conteúdo deste ZIP (preserve sua configuração publicável em `docs/config.js` caso seja diferente) e publique `main` / `docs` como de costume. Atualize o navegador (Ctrl+F5).
5. Em Cartões de crédito, selecione o banco e cartão cadastrados, importe o PDF e confira vencimento, total oficial, saldo anterior, gastos, créditos e pagamentos. Confirme somente se a diferença for zero e os itens estiverem corretos.

## Alterações

- Leitores posicionais de Santander e Bradesco (layouts A4 das amostras): colunas independentes, moeda BRL, USD informativo, parcelas, final do cartão, pagamentos, estornos e encargos. IOF sem data recebe a data da compra internacional anterior; confira na revisão. Datas sem ano são inferidas pelo vencimento conforme a regra anterior; confira compras muito antigas.
- OCR opcional: reaproveita palavras posicionadas quando disponíveis. OCR e layouts diferentes podem exigir correção manual. Leitor genérico mantido para demais instituições e formatos. Não há upload de PDFs ou imagens para serviços de interpretação; as bibliotecas são carregadas pelos CDNs já utilizados no projeto.
- CSV Nubank mantém o parser e a exclusão de pagamentos anteriores do fluxo original. A nova RPC é chamada quando há saldo anterior, metadados, pagamentos ou encargos explícitos; demais fluxos podem usar RPC anterior.
- Conciliação: saldo anterior + compras/encargos + créditos (negativos) + pagamentos (negativos) = total oficial. Pagamentos não fazem parte dos gastos por categoria. Apenas o total oficial vira lançamento no fluxo de caixa. Não há ajuste automático para forçar o fechamento.
- Compras legítimas repetidas são mantidas. Índices existentes impedem duplicidade por arquivo (SHA-256) e cartão/vencimento. Cartões adicionais ficam detalhados pelo final, sem cadastrar outro cartão automaticamente.
- Migração preserva faturas anteriores, sem recategorizar registros históricos. Mantém o limite anterior de faturas com total positivo e 1 a 2000 itens. Faturas zeradas/credoras não são suportadas nesta versão.

## Testes

`node --test tests/*.test.cjs` — testes originais e novos, fixtures sintéticas sem dados pessoais. A leitura posicional também foi exercitada com o texto extraído localmente dos dois PDFs fornecidos: Santander 42 movimentos, total conciliado R$ 1.145,29; Bradesco 7 movimentos, total conciliado R$ 133,86; ambas com diferença zero.

A execução real do PDF.js e do OCR depende da conexão aos CDNs; a migração deve ser homologada no Supabase e o CSV real do Nubank deve ser testado no navegador. Não foram incluídas as faturas originais nem credenciais adicionais no ZIP. Nenhuma publicação ou alteração em banco remoto foi feita.

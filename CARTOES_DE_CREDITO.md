# Cartões de crédito — instalação e homologação
> Documento histórico da V1. Para instalar a versão atual, siga BANCOS_E_CARTOES_V2.md; as migrações e o cadastro mudaram.

A implementação preserva a arquitetura HTML/CSS/JS, Supabase e GitHub Pages. Nenhum serviço adicional de backend é necessário.

## Implantação

1. Faça backup do banco e use primeiro um projeto Supabase de homologação com as migrações 01 e 04 aplicadas e os usuários provisionados.
2. Execute `database/06-credit-cards.sql` no SQL Editor uma única vez. Migração aditiva; não modifica valores existentes. Se a migração falhar, a transação é revertida.
3. Execute `database/07-test-credit-cards.sql` no banco de homologação. O teste usa os ambientes `pessoal-a` e `pessoal-b` do provisionamento original e encerra com ROLLBACK. Não execute em produção sem validação prévia.
4. Publique a pasta `docs/` completa, preservando a configuração publicável do Supabase apropriada para o ambiente. Não publique dados financeiros ou chaves secretas. Em GitHub Pages, a origem HTTPS é necessária para SHA-256 no navegador.
5. Atualize o aplicativo no navegador/PWA. No menu Cartões de crédito (no celular, Mais > Cartões de crédito), importe uma fatura de teste.

## Uso

- Selecione o ambiente pessoal ou familiar e o mês/ano de vencimento. Abra Nova fatura / Importar, informe um nome estável para o cartão, data de vencimento e o total oficial a pagar.
- Selecione CSV ou PDF. Confira as linhas não reconhecidas e os possíveis pagamentos anteriores excluídos. Edite datas, descrições, categorias e valores; remova ou acrescente itens manualmente. Estornos e créditos são negativos. Informe encargos ou saldo anterior efetivamente devido se fizerem parte do total oficial, sem repetir pagamento ou compras já contabilizadas.
- CSV: cabeçalhos Data, Descrição, Valor ou date, title, amount, com separador ponto e vírgula, vírgula ou tabulação. UTF-8 ou Windows-1252. Valores BRL, sem conversão cambial. PDF: texto selecionável em linhas no formato data + descrição + valor final; a leitura usa PDF.js 5.4.624 via jsDelivr, com worker de mesma origem. PDFs digitalizados, protegidos, em múltiplas colunas ou com layouts diferentes podem exigir CSV ou revisão manual. Não há OCR. Datas sem ano são inferidas em relação ao vencimento; confira especialmente na virada do ano.
- Confirme apenas quando a soma líquida coincidir exatamente com o total oficial. Se a fatura já estiver lançada manualmente com o mesmo valor e vencimento, selecione o lançamento existente. A associação preserva o pagamento e muda a categoria e descrição para identificar a fatura. Se houver um lançamento com valores diferentes, regularize-o antes de importar.
- O banco grava uma despesa única e seus itens em uma única transação. A categoria principal é Cartão de crédito. O detalhamento por categoria é separado; o dashboard geral e os orçamentos atuais contabilizam somente a fatura, não cada compra. Não lance o pagamento da fatura como uma segunda despesa. Marcar Realizar muda o status da mesma despesa. Excluir a fatura remove também o detalhamento; para corrigir uma fatura confirmada, exclua e reimporte, revendo o status de pagamento.
- O arquivo bruto não é armazenado. A leitura usa o navegador; só os dados confirmados e a impressão digital SHA-256 do arquivo são enviados ao Supabase. A CDN fornece código da biblioteca PDF.js, não recebe o documento como parâmetro. A migração preserva o isolamento RLS de ambientes. A duplicidade é bloqueada por cartão/vencimento e por hash do arquivo dentro do ambiente. Nomes diferentes e arquivos alterados podem demandar conferência manual.
- Não há cadastro bancário, limites de cartão, antecipação de parcelas, OCR, aprendizado de classificação ou integração automática com bancos nesta versão. Faturas líquidas de valor zero ou negativo não são suportadas pelo modelo de despesas existente. Limites de leitura: 15 MB, 100 páginas PDF, 2.000 itens.

## Testes

`node tests/card-parser.test.cjs` e `node --check` nos JS/MJS. São testes locais; o SQL precisa ser validado no Supabase e o PDF em navegador com internet e arquivos reais de cada emissor. Para homologar, confira: importação CSV e PDF, inclusão manual, créditos, total divergente, reimportação, vínculo de despesa anterior, pagamento, exclusão, isolamento pessoal/familiar, mudança de período e navegação móvel.

Exemplo CSV (dados fictícios, não versionar arquivos reais):

```csv
Data;Descrição;Valor
01/11/2026;UBER TRIP;25,90
02/11/2026;SUPERMERCADO;125,00
03/11/2026;ESTORNO;-5,00
```
Total oficial: R$ 145,90.

Validação desta entrega: os testes do parser e a checagem de sintaxe foram executados com sucesso. A tentativa de executar o fluxo de navegador com Supabase simulado foi bloqueada pela política de navegação do ambiente de execução (`ERR_BLOCKED_BY_ADMINISTRATOR`), portanto não constitui teste de integração aprovado. Os testes SQL foram preparados, mas não executados contra um Supabase real; a extração PDF com a biblioteca em execução também não foi validada aqui. Use uma fatura real anonimizada de cada emissor para homologar antes da publicação.

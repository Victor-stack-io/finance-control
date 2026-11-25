# Finance Control V4 — Mobile First

Projeto completo, baseado na V2, com os arquivos originais preservados e evolução integrada ao frontend e Supabase. O HTML do protótipo V4 é uma demonstração independente, não deve substituir docs/index.html.

## Implantação (homologação primeiro)
1. Faça backup do banco e da versão publicada. Não execute novamente migrações já aplicadas.
2. Se o banco está na versão original Premium, execute `database/06-credit-cards.sql`, `database/08-banks-and-cards.sql`, depois `database/10-card-analytics.sql`. Se está na V1, execute apenas 08 e 10; se está na V2, execute apenas 10. Os scripts 07 e 09 são testes específicos de suas versões, não migrações. Para instalação desde o zero consulte README.md e os guias anteriores.
3. Publique a pasta `docs/` completa no ambiente de homologação do GitHub Pages, preservando a configuração publicável Supabase correspondente ao ambiente. Não use chaves secretas. Atualize o navegador/PWA.
4. Valide com dois bancos, cartões diferentes, faturas de dois meses e um estorno. Teste a criação de categoria e limite, alteração de classificação de compra, memória na próxima importação e isolamento entre ambientes. Verifique se o total oficial é debitado apenas uma vez do saldo. Confira o PDF real de cada banco; PDFs digitalizados não são aceitos.
5. Antes de produção, confirme as políticas RLS das novas tabelas e RPCs com usuários de ambientes distintos. Verifique que o usuário sem associação ao ambiente não lê nem altera registros daquele ambiente.

## Arquivos novos
- `docs/card-analytics-model.js`: cálculos puros, filtros, agrupamentos e chaves de classificação.
- `docs/card-analytics.js`: gráficos, ranking, comparação, limites, cadastro de categorias, reclassificação e importação com memória.
- `docs/card-analytics.css`: ajustes mobile e identidade visual Premium.
- `database/10-card-analytics.sql`: tabelas e funções com controle de acesso por workspace.
- `tests/card-analytics.test.cjs`: testes automatizados de cálculo.

## Arquivos atualizados
`docs/index.html`, `docs/app.js`, `docs/cards.js`, `docs/premium.js`. Entrega inclui todos os arquivos do projeto, não apenas os alterados.

## Regras
- Período pelo vencimento; o total de faturas é único e já integra as despesas. Análises de compras não alteram saldo.
- Limites por categoria são exclusivos do cartão e consideram todos os bancos e cartões. Na visão anual o limite mostra o mês de referência selecionado (ou janeiro do ano selecionado se não coincidir).
- Classificações memorizadas por descrição normalizada (acentos, maiúsculas, espaços e sufixo de parcela), não por IA externa. Marque Memorizar para salvar; regras são compartilhadas dentro do mesmo workspace, não entre workspaces.
- Ranking agrupa alguns nomes conhecidos (Uber, 99, iFood, Cobasi); outros por descrição normalizada. Gráfico circular mostra categorias com saldo líquido positivo; estornos negativos aparecem no ranking e totais.
- O total oficial deve reconciliar com a soma dos itens; pagamentos anteriores excluídos, estornos negativos. Sem pagamento parcial, OCR, nem edição/exclusão de banco e cartão nesta versão.

## Validação realizada
- `node --test tests/*.cjs`: 3 suites, 51 verificações declaradas pelos scripts.
- `node --check` nos scripts JS.
- Chromium: teste de renderização com dados simulados, sem rede, injeção local do HTML/CSS/JS (sem CSP real), Overview e Cartões a 320, 390 e 1440 px, sem overflow horizontal; filtro de categoria, limite excedido e abertura de diálogo de classificação.
- Não foi executado SQL no Supabase real, nem testada autenticação, gravação real, CSP/serviço HTTP, PWA ou leitura de PDF real. Homologação obrigatória. Nenhuma alteração no GitHub/produção.

# Finance Control — Premium 2.1 | Atualização

Pacote incremental para a estrutura existente do repositório (GitHub Pages em `docs/`). Não contém `config.js`, credenciais, dados fictícios, ícones nem arquivos de provisionamento: preserve esses arquivos existentes.

## Ordem obrigatória
1. Faça backup do banco Supabase e mantenha o commit atual do GitHub como referência de rollback.
2. No SQL Editor do **mesmo** projeto Supabase, execute `database/04-premium.sql` integralmente, uma única vez. Não execute novamente `01-schema.sql` nem `02-provision.sql`. A migração é transacional e aditiva; não exclui registros existentes.
3. Rode `database/05-test-premium.sql` e, se desejar, o `03-test-rls.sql` original. O teste usa os ambientes provisionados `pessoal-a`, `pessoal-b`, `familiar` e termina com ROLLBACK. Se houver erro, não publique até resolver. Não foi executado contra o Supabase real nesta entrega.
4. Extraia este ZIP sobre a raiz do repositório, mantendo as pastas `docs/` e `database/`. Faça commit dos arquivos do pacote. Preserve os demais arquivos (principalmente `docs/config.js`).
5. Aguarde a publicação normal do GitHub Pages, recarregue a página e faça login. Teste no desktop e no celular. Em PWA, se necessário feche e reabra o aplicativo conectado à internet.

## Regras adotadas
- Conta fixa tem tipo, categoria, descrição, valor, dia (ajustado ao último dia de meses curtos), mês inicial e término opcional. Cadastro a partir do mês corrente ou futuro. As previsões são calculadas sem gravar 12 lançamentos. Ao realizar ou editar uma ocorrência, grava-se um lançamento vinculado, único por recorrência e mês. Uma previsão sem lançamento materializado não pode ser excluída isoladamente nesta versão; encerre a regra ou ajuste sua ocorrência.
- Alterações criam nova versão da regra a partir do próximo mês ou posterior; lançamentos futuros vinculados bloqueiam a alteração para evitar duplicidade. Encerramento mantém lançamentos já salvos e o mês corrente (se já iniciada). Excluir lançamento vinculado restaura previsão apenas se a regra ainda cobrir aquele mês.
- Lançamentos manuais antigos não são automaticamente convertidos em recorrências. Evite cadastrar conta fixa para um mês que já possui o lançamento manual correspondente; comece no mês seguinte para não contar duas vezes.
- Indicadores por competência de vencimento, não por saldo bancário. Realizado = receitas recebidas menos despesas pagas; previsto = receitas e despesas pagas + pendentes, inclusive recorrências. Sem integração bancária.
- Orçamentos são limites mensais atuais por categoria; o anual multiplica por 12. Alterar limite muda a referência exibida também em períodos anteriores. Metas são acompanhadas manualmente e não modificam lançamentos.
- Mesmo login e modelo de acesso por ambiente, sem cache de dados financeiros. O layout aplica o conceito visual aprovado à estrutura autenticada original; não é uma cópia pixel a pixel do HTML demonstrativo.

## Homologação recomendada
- Login, recuperação de senha e troca de ambientes; verificar que um usuário não vê dados pessoais de outro.
- Criar conta fixa de despesa e receita; navegar para meses futuros e comparar anual. Testar dia 31 em fevereiro, baixa, edição e ausência de duplicação.
- Criar e editar lançamento manual, orçamento, meta, exportação CSV, tema e categorias.
- Testar encerramento e edição futura da recorrência e verificar que o histórico continua disponível.
- Testar menu inferior, cartões, formulários e PWA em aparelho físico.

## Validação realizada
JavaScript verificado com Node; testes em Chromium com API Supabase simulada passaram para cadastro de recorrência, previsão, baixa, visão anual, orçamento e meta. Layout overview sem rolagem horizontal nas larguras 320, 390, 430 e 1440 px. Nenhum acesso ao Supabase real, nenhuma alteração no GitHub, nenhuma validação de SQL/RLS em servidor PostgreSQL nesta sessão. Os testes de navegador simulado não substituem homologação do SQL real.

## Rollback
Se necessário, reverta somente o commit de frontend para a versão anterior; as tabelas aditivas podem permanecer. Não exclua tabelas nem colunas sem análise e backup, especialmente após criar registros novos.

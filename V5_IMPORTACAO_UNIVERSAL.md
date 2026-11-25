# Finance Control V5 — Importação bancária ampliada

Base: ZIP V4 Mobile First. A estrutura do projeto, Supabase e dashboards foi preservada. A V5 não exige migração adicional: utiliza as tabelas e RPCs das migrações 06, 08 e 10 já existentes. Nenhum dado pessoal de teste foi incluído.

## Instalação e homologação
1. Faça backup e confirme que as migrações da V4 estão aplicadas; se não estiverem, siga `V4_MOBILE_INSTALACAO.md` (não repita migrações já executadas).
2. Publique **todo** o diretório `docs/` em homologação via HTTPS, preservando a configuração Supabase publicável do ambiente. Não exponha chave secreta. Atualize a página/PWA.
3. Cadastre banco e cartão. Informe o vencimento real e total oficial, selecione o arquivo e revise os dados extraídos, itens ignorados, sinais, categorias e eventual banco sugerido. A identificação não muda o cartão automaticamente. A senha opcional do PDF fica apenas no campo de formulário durante a tentativa, não é enviada ao Supabase.
4. Para imagens ou PDFs sem texto, abra Opções avançadas e habilite OCR experimental. Valide a extração visualmente, inclusive centavos, datas e sinais. Não há garantia de detecção de todas as linhas. O limite é 15 MB, 100 páginas textuais, 10 páginas digitalizadas, 2000 lançamentos. PDF misto com páginas pouco textuais é heurístico.
5. Compare com a fatura. O total oficial positivo precisa coincidir com a soma dos itens para salvar. Pagamentos anteriores identificados são excluídos da lista de consumo; se houver saldo anterior, pagamento parcial ou outros ajustes, a divergência não é corrigida automaticamente. Não crie gastos fictícios para forçar conciliação. O modelo V4 ainda não representa pagamentos parciais ou faturas com total zero/credor de modo autônomo.
6. Teste duplicidade entre CSV e PDF da mesma fatura: a chave de cartão/vencimento existente no Supabase impede uma segunda fatura para o mesmo ciclo exato; o hash impede importar o mesmo arquivo novamente. Não há fingerprint semântico de todas as compras entre formatos; vencimento e cartão precisam estar corretos. Linhas iguais no mesmo arquivo são sinalizadas, não apagadas.
7. Verifique Overview, rankings, categorias, memória de classificação, limites e parcelas futuras. Projeção é estimativa baseada nas descrições com parcela reconhecida da última fatura disponível até a referência, por cartão, dentro do histórico carregado (ano selecionado e dezembro anterior). Não gera lançamentos; não representa compromisso confirmado nem todos os formatos de parcelamento. Valide cartões com vários meses e mudança de ano.
8. Valide autenticação, persistência, RLS e RPCs com dois workspaces. Só publique em produção após a homologação.

## Alterações
- `docs/card-import-model.js`: catálogo de 37 emissores, sugestão de instituição por nome de arquivo/cabeçalho, normalização de linhas PDF, leitura de tabela e OFX de cartão em BRL, reconhecimento e projeção de parcelas.
- `docs/card-import.js`: despacho CSV, OFX, XLS/XLSX, PDF (senha opcional) e JPG/PNG (OCR experimental); processamento no navegador.
- `docs/ocr-worker.js`: worker de mesma origem para OCR.
- `docs/card-parser.js`: colunas CSV adicionais e categorias ampliadas.
- `docs/cards.js`, `docs/index.html`, `docs/card-analytics.js`: integração com revisão, seleção de banco, projeções e indicadores existentes.
- `tests/card-import.test.cjs`: 6 testes novos com múltiplas verificações; 3 suites antigas preservadas.

## Dependências e segurança
O projeto carrega bibliotecas no navegador sob demanda: PDF.js 5.4.624 (jsDelivr, já utilizada na V4), SheetJS CE 0.20.3 (CDN oficial) e Tesseract.js 6.0.1, core 6.0.0 e dados de idioma português (jsDelivr). A CSP foi ampliada para os hosts específicos e compilação WebAssembly (`wasm-unsafe-eval`), não para `unsafe-eval` geral. Não há endpoint de upload de documentos no código; apenas os dados confirmados são gravados no Supabase. A execução de bibliotecas externas requer rede e confiança nesses distribuidores; antes de produção, recomenda-se hospedar e verificar os artefatos/licenças/hashes localmente e testar CSP real. Bibliotecas não estão vendorizadas no ZIP. OCR pode consumir memória e bateria; não é obrigatório para CSV/PDF textual.

Referências: https://docs.sheetjs.com/docs/getting-started/installation/standalone/ ; https://mozilla.github.io/pdf.js/api/draft/module-pdfjsLib-PDFDocumentLoadingTask.html ; https://github.com/naptha/tesseract.js . Nenhum código de parser de terceiros foi copiado de BankSheet ou Statement Parser.

## Matriz de compatibilidade
| Recurso | Estado nesta entrega |
|---|---|
| CSV Nubank | Testado com amostra real (10 registros, 309,24 em gastos líquidos após excluir pagamento) |
| CSV universal | Testes sintéticos de colunas/datas/separadores |
| Catálogo de emissores | 37 sugestões; cadastro manual de outros bancos permitido |
| PDF textual | Normalização e parser de linhas testados com amostras sintéticas; extração de arquivo real pendente |
| Leitores especializados por banco | Não homologados; catálogo não equivale a suporte comprovado. O leitor PDF é compartilhado e heurístico. |
| PDF protegido | Integração de senha no PDF.js; pendente de teste real |
| XLS/XLSX | Adaptador integrado; parser de tabela testado, leitura binária via SheetJS pendente |
| OFX de cartão | Teste sintético, BRL; não aceita extrato de conta corrente; revisar convenção de sinais do banco |
| OCR JPG/PNG e PDF digitalizado | Experimental, integração implementada, execução real pendente |
| Parcelas futuras | Teste sintético de reconhecimento e projeção; sem lançamentos futuros automáticos |
| Mobile | Teste Chromium com dados simulados a 320/390/1440px em Overview e Cartões; sem overflow horizontal |
| Supabase | Sem migração V5; autenticação/persistência/isolamento reais pendentes |

A rede do ambiente de construção não resolve as CDNs; por isso não foi possível testar a leitura binária PDF/XLS ou o OCR no navegador. Testes de interface simulados não validam a CSP efetiva. Não houve alteração em GitHub ou produção.

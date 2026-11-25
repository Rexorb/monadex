# Registro de desenvolvimento

## Fase 0 — 2026-11-24

**Concluído:** inspeção dos arquivos, inventário de ferramentas, verificação não destrutiva de portas e documentação inicial. Diretório original: apenas `projectcontext.md`; nenhum scaffold ou código Haskell. Docker daemon respondeu com versão 29.8.1. Porta 5432 ocupada; 5433 sem listener no instante da inspeção.

**Ferramentas:** GHC/GHCi 9.4.7; Stack 3.9.3; Cabal 3.8.1.0; Docker 29.8.1; Docker Compose v5.5.1; cliente psql 18.6. Nenhum pacote Yesod/Persistent/Hspec foi encontrado na consulta ao banco global do GHC; isso não descarta instalações em snapshots Stack.

**Comandos de inspeção:** `pwd`, `ls -la`, `find . -maxdepth 2 -type f`, `command -v`, `ghc --version`, `ghci --version`, `stack --version`, `stack ls snapshots`, `cabal --version`, `ghc-pkg list`, `docker --version`, `docker info --format '{{.ServerVersion}}'`, `docker compose version`, `psql --version`, `ss -ltn`. Tentativa `stack path --snapshot-root` retornou opção inválida; não alterou arquivos.

**Build e testes:** não executados: não existe projeto compilável nesta fase. **Pendências:** selecionar resolver compatível, obter dependências se necessário, configurar banco isolado e verificar migrations/servidor na Fase 1. **Próxima etapa:** iniciar Fase 1 somente com autorização do usuário.

## Fase 1 — 2026-11-24

**Implementado:** fundação Yesod sem interface, endpoint JSON `GET /`, pool PostgreSQL configurado por `DATABASE_URL`, seis entidades Persistent, migrations e três CHECKs SQL iniciais; Compose com PostgreSQL 16, healthcheck, volume persistente e porta 5433 no loopback. `.env` local com senha aleatória criado e ignorado pelo Git.

**Arquivos:** `stack.yaml`, `package.yaml`, `app/Main.hs`, `src/{Application,Foundation,Model}.hs`, `src/Handler/Home.hs`, `docker-compose.yml`, `.env.example`, `.gitignore`, `README.md` e documentação em `docs/`. Nenhum frontend criado.

**Comandos:** `stack build --fast`; `docker compose config --quiet`; `docker compose up -d --wait db`; `stack exec monadex`; `curl -i http://127.0.0.1:3000/`; consulta `psql` às tabelas e restrições. Build concluiu; banco saudável; migrations aplicadas; HTTP 200 com JSON `"monadex backend online"`; seis tabelas e três CHECKs iniciais confirmados. Reinício do servidor não falhou. Servidor de teste encerrado; container e volume do banco permanecem ativos.

**Problemas:** Hpack rejeitou `github: ""`; extensões QuasiQuotes, OverloadedStrings e extensões exigidas pelo Persistent foram adicionadas. Avisos de código gerado por Template Haskell não impedem o build.

**Testes:** smoke test HTTP e inspeção do esquema; ainda não há suíte Hspec nem testes de concorrência. **Pendências:** domínio, tipo `Rarity` em Haskell, catálogo, autenticação, concorrência e segurança de sessão de produção. **Próxima etapa:** Fase 2 somente após autorização.

## Fase 2 — 2026-11-24

**Implementado:** `Domain.Rarity` (categorias, pesos e seleção pura); `Domain.Card` e `Domain.Error`; `Domain.Player` (estado e concessão diária); `Domain.Booster` (sorteio com `StdGen` explícito e `StateT`/`Either` para consumo e coleção). A sexta carta usa pesos relativos configuráveis 25/10/5 para Incomum/Rara/Ultra-rara. Catálogo sem alguma categoria retorna erro sem redistribuir pesos. Nenhuma rota, acesso ao banco ou frontend foi alterado nesta fase.

**Arquivos:** adicionados `src/Domain/{Rarity,Card,Error,Player,Booster}.hs`, `test/Spec.hs`; alterados `package.yaml`, `README.md`, `docs/{MONADS,BUSINESS_RULES,ROADMAP,TESTING,DEVELOPMENT_LOG}.md`.

**Decisão:** regras em funções puras antes da integração. `drawBooster` recebe/devolve gerador para reprodutibilidade; `openBooster` recebe cartas sorteadas, valida o pacote e altera estado em memória, sem pretender substituir a transação PostgreSQL. `claimDailyReward` recebe o dia, cuja conversão segura de fuso horário é pendência de integração.

**Comandos:** `stack test --fast` (compila biblioteca, executável e suíte Hspec). **Build:** passou, com avisos gerados por Template Haskell do Persistent. **Testes:** 12 exemplos Hspec, 0 falhas; sorteio validado com 101 sementes fixas.

**Problemas:** nenhuma incompatibilidade nova de dependências; `hspec`, `random`, `mtl` e `containers` foram resolvidos pelo snapshot. **Pendências:** conectar domínio às entidades Persistent (incluindo tipagem de raridade), obter catálogo real, gerar aleatoriedade no servidor, data America/Sao_Paulo, transações e concorrência. **Próxima etapa:** Fase 3, somente após autorização.

## Fase 3 — 2026-11-24

**Implementado:** TCGdex HTTPS/JSON com timeout e erros explícitos; normalização sem default para raridades desconhecidas; importação por CLI `--import-set swsh12`, validação do catálogo completo antes da gravação, upserts idempotentes e `Card.rarity` tipado em Haskell. Nenhum endpoint de usuário ou frontend foi implementado.

**Arquivos:** `src/Service/{CardAPI,CardImportService}.hs`; alterados `src/Domain/Rarity.hs`, `src/Model.hs`, `app/Main.hs`, `package.yaml`, `test/Spec.hs`, `README.md` e `docs/{API_INTEGRATION,ARCHITECTURE,DATABASE,MONADS,ROADMAP,TESTING,TECHNICAL_DECISIONS,DEVELOPMENT_LOG}.md`.

**Comandos:** `curl`/`jq` nos endpoints `/sets/swsh12`, `/cards/swsh12-001` e `/rarities`; `stack build --fast`; `stack test --fast`; `stack exec monadex -- --import-set swsh12` duas vezes; consulta SQL com `docker compose exec -T db psql` para contagem de cartas, expansões, duplicatas e raridades.

**Resultados:** duas importações concluíram com `ImportReport {importedCards = 215, skippedRarities = fromList []}`. Banco após repetir: 1 expansão, 215 cartas, 0 IDs externos duplicados; Common 53, Uncommon 56, Rare 35, UltraRare 71. Build passou; 17 exemplos Hspec passaram (0 falhas). O serviço PostgreSQL do projeto permaneceu saudável.

**Problemas e decisões:** ID `swsh12-1` respondeu 404; a API usa `swsh12-001`. Campo de espécie Pokémon não confiável/ausente: persistido como opcional vazio. A listagem da expansão não contém raridade, portanto cada carta é consultada separadamente. O log inicial do Persistent gerava muitas linhas com dados das cartas; execução padrão agora usa `runNoLoggingT`. Não houve mudança no banco de outro projeto.

**Pendências:** testes Hspec de integração SQL e de falhas HTTP simuladas; autenticação e isolamento por conta; abertura/recompensa transacionais; geração segura de aleatoriedade e data local America/Sao_Paulo no servidor. **Próxima etapa:** Fase 4, somente após autorização.

## Fase 4 — 2026-11-24

**Implementado:** cadastro com username único, hash PBKDF2-HMAC-SHA256 com salt aleatório, confirmação de senha, criação de inventário zero na mesma transação, login/logout com sessão Yesod, chave local não versionada e modo 0600, CSRF, rota privada `/dashboard` limitada à própria conta e limite persistido de tentativas por username. O frontend permanece de responsabilidade de outro dev.

**Arquivos:** `src/Service/AuthService.hs`, `src/Handler/{Auth,Dashboard}.hs`, `src/{Foundation,Application,Model}.hs`, `app/Main.hs`, `test/Spec.hs`, `package.yaml`, `.gitignore`, `.env.example`, `README.md` e `docs/{AUTH_API,ARCHITECTURE,DATABASE,MONADS,ROADMAP,TESTING,TECHNICAL_DECISIONS,DEVELOPMENT_LOG}.md`.

**Comandos:** `stack build --fast`, `stack test --fast`, `stack exec monadex`, `curl` com cookies/JSON/CSRF para rotas públicas e privadas, consulta `docker compose exec -T db psql` aos hashes, inventário e tentativas. Um teste inicial enviou `X-CSRF-Token` e recebeu 403; a documentação Yesod e a resposta de erro indicaram `X-XSRF-TOKEN`, usado corretamente nos testes seguintes.

**Resultados:** build passou; 19 exemplos Hspec passaram, zero falhas. Smoke HTTP: sem CSRF 403; registro 201; duplicata 400; dashboard autenticado 200 e anônimo 401; logout 200; login inválido 401 e válido 200. SQL confirmou senha diferente do texto fornecido, inventário inicial zero, e contador limitado a cinco após seis falhas consecutivas. Arquivo `.session-key` conferido com modo 0600. Servidor de teste encerrado; PostgreSQL permanece ativo. Dados de demonstração identificados (`demo_phase4` e `absent_phase4`) foram removidos após os testes, sem tocar outros registros.

**Decisões/pêndencias:** hash `cryptonite`, username normalizado e CSRF do Yesod; proteção Secure configurável para produção. Testes de integração SQL/HTTP ainda são manuais; limites complementares por IP, implantação HTTPS e cobertura automatizada de concorrência não foram validados. Dashboard ainda não contém estatísticas do jogo nem concessão diária. **Próxima etapa:** Fase 5 somente após autorização.

## Fase 5 — 2026-11-25

**Implementado:** concessão inicialmente automática de um booster por dia por conta no fuso `America/Sao_Paulo` (comportamento posteriormente substituído pelo `POST /rewards/daily/claim`); abertura backend de seis cartas usando o catálogo local e domínio puro, persistindo consumo, coleção agregada e histórico ordenado em uma transação. Dashboard e consultas JSON privadas de boosters, último resultado, coleção filtrada e expansões com progresso por cartas únicas. Nenhuma página ou mecanismo de monetização foi criado.

**Arquivos:** `src/Service/{DailyRewardService,BoosterService,CollectionService}.hs`, `src/Handler/{Player,Booster,Collection}.hs` e alterações em `src/Handler/Dashboard.hs`, `src/{Foundation,Application,Model}.hs`, `app/Main.hs`, `package.yaml`, `.env.example`, `test/{Spec,Integration}.hs`, `README.md`, `docs/{BACKEND_API,AUTH_API,ARCHITECTURE,BUSINESS_RULES,DATABASE,MONADS,ROADMAP,TESTING,TECHNICAL_DECISIONS,DEVELOPMENT_LOG}.md`.

**Decisões:** timezone Olson do servidor (não offset fixo nem data de cliente); bloqueio `SELECT ... FOR UPDATE` da linha User comum às duas operações, com `runDB` transacional; semente aleatória gerada no backend; `BoosterOpening` e `BoosterOpeningCard` para consultar o resultado persistido sem gastar outra unidade; testes de integração somente em `monadex_test_db`. O executável e a suíte passaram a usar runtime threaded com duas capacidades.

**Comandos:** `stack build --fast`, `stack test --fast` com `MONADEX_TEST_DATABASE_URL` isolada, `docker compose exec -T db psql` para criar/verificar banco de testes, `stack exec monadex`, `curl` com cookies/CSRF para endpoints e duas requisições simultâneas, consultas SQL de inventário/coleção/recompensa/histórico. Build passou; **22 exemplos Hspec, 0 falhas** com integração SQL. Testes HTTP: primeiro acesso concedeu um booster; acessos repetidos no dia não concederam outro; abertura retornou seis cartas, sexta Rare ou Uncommon nos ensaios; abrir sem booster deu 409. Progresso/filtros e última abertura foram consultados por GET, sem consumo. Duas aberturas concorrentes com um booster: 200 e 409, inventário final zero e somente seis cartas novas. Duas consultas simultâneas para recompensa: dois HTTP 200, uma concessão, uma linha DailyReward e inventário um. Duas contas mostraram coleções isoladas. Banco de testes automatizados confirmou isolamento, concorrência e um único histórico.

**Problema encontrado:** teste inicial de duas requisições simultâneas bloqueou no runtime Haskell não threaded; uma conexão aguardava a linha bloqueada enquanto outra permanecia em transação. Encerrei somente o servidor de teste do projeto, compilei executável/testes com `-threaded -with-rtsopts=-N2` e repeti com sucesso. Demais serviços e bancos não foram alterados.

**Limpeza:** removidas somente as contas de demonstração `phase5_demo`, `phase5_reward_demo` e `phase5_race_new` com seus registros vinculados; o catálogo real permanece em `monadex_db`. Banco separado `monadex_test_db` e suas fixtures fictícias identificadas foram preservados para repetir os testes. Servidor de teste encerrado; container PostgreSQL do projeto permanece ativo.

**Pendências:** testes automatizados HTTP completos e falhas simuladas da API externa; revisão de segurança/HTTPS e documentação de implantação; escolha de tratamento de grandes catálogos/paginação se necessário. Frontend e identidade visual continuam delegados ao outro desenvolvedor. **Próxima etapa:** revisão final do backend e integração com o frontend somente após autorização.

## Revisão técnica pré-commit 02 — 2026-11-25

A revisão gerou o commit 02; esta documentação prepara o commit 03.

**Correção do contrato:** GETs privados passaram a ser somente leitura; `Handler.Player.authenticatedPlayer` não concede recompensa. `GET /dashboard` consulta `dailyRewardStatus`. `POST /rewards/daily/claim` recebe sessão e CSRF, usa data do servidor no fuso São Paulo e retorna HTTP 200 com `grantedNow: false` quando já concedida, sem novo crédito. O frontend pode chamar o POST no fluxo inicial autenticado. Commit 01 (`projectcontext.md`) não foi modificado.

**Segurança/persistência:** erros HTTP comuns padronizados em JSON sem expor detalhes internos; cookie de sessão `_SESSION` HttpOnly e SameSite=Strict conferido no teste Yesod; Secure requer HTTPS e configuração de produção. CORS opcional aceita uma origem exata por `FRONTEND_ORIGIN`, sem curinga com credenciais; HTTP somente em loopback. `Model.migrateMonadex` centraliza migrations do servidor e banco de testes, com CHECKs para inventário, quantidade da coleção, raridade e posição do histórico. Nenhum esquema do banco de desenvolvimento foi alterado durante esta revisão.

**API/testes:** `fetchWith` recebe transporte injetado para falhas TCGdex simuladas sem acesso à rede na suíte. `test/HttpSpec.hs` usa yesod-test em `monadex_test_db` para cadastro, login, logout, CSRF, GET sem recompensa, POST repetido, abertura, histórico e isolamento. O teste SQL existente também verifica migrations repetidas, CHECKs, rollback de inventário negativo, fixture idempotente, duas concessões/aberturas concorrentes e novo dia com relógio controlado. Testes de frontend não foram criados.

**Consistência de leitura:** `GET /dashboard`, `GET /boosters/last` e `POST /rewards/daily/claim` passaram a resolver seus dados em uma única ação `runDB`, reduzindo a intercalação entre transações; as mutações continuam serializadas pelo lock de linha, e as leituras seguem o isolamento READ COMMITTED do PostgreSQL. O login de username inexistente executa uma verificação PBKDF2 descartável (`placeholderHash`) para reduzir enumeração por tempo, mantendo a mesma mensagem genérica.

**Comandos/resultados:** `stack build --fast` passou; `stack test --fast` com `MONADEX_TEST_DATABASE_URL` apontando exclusivamente a `monadex_test_db` passou com **27 exemplos, 0 falhas, 0 pendentes**. Preflight CORS manual (servidor conectado apenas ao banco de testes) aceitou origem local configurada com HTTP 200 + `Access-Control-Allow-Credentials: true` e rejeitou outra com HTTP 400. Uma execução intermediária dos testes falhou na verificação SameSite porque a fábrica do site de teste não aplicava o middleware de sessão da aplicação; a fábrica foi corrigida e a suíte final passou. Warnings gerados por Persistent (`-Wname-shadowing`) e pelo dispatcher Yesod (`-Worphans`) permanecem visíveis, sem supressão global.

**Pendências:** não houve validação HTTPS/cookie Secure atrás de proxy; concorrência de serviços foi automatizada em SQL, mas não há teste HTTP concorrente. Limitação de login por IP/rede ainda exige planejamento de implantação; histórico grande pode exigir paginação; o banco de testes compartilhado acumula contas/fixtures entre execuções; a importação não remove cartas que o fornecedor tenha excluído. Os contratos HTTP atualizados em `docs/AUTH_API.md` e `docs/BACKEND_API.md` substituem o comportamento histórico de concessão em GET descrito acima na Fase 5.

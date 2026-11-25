# Arquitetura do backend

Monólito Haskell/Yesod, sem templates e sem frontend próprio. A interface será desenvolvida por outra integrante e consome os contratos HTTP/JSON documentados em `BACKEND_API.md` e `AUTH_API.md`.

## Módulos e responsabilidades

| Camada | Módulos | Responsabilidade |
| --- | --- | --- |
| Inicialização | `app/Main.hs` | Lê ambiente, cria pool PostgreSQL, aplica migrations, carrega fuso/chave de sessão, valida CORS e inicia Warp; também executa `--import-set`. |
| Infraestrutura Yesod | `Application`, `Foundation` | Dispatcher de rotas, instância `Yesod`/`YesodPersist`, middleware de sessão/CSRF, autorização de rotas privadas, tratamento JSON de erros e `runDB`. |
| Persistência | `Model` | Entidades Persistent, unicidades, FKs e `migrateMonadex` com os quatro CHECKs SQL. |
| Domínio puro | `Domain.Rarity`, `Domain.Card`, `Domain.Error`, `Domain.Player`, `Domain.Booster` | Pesos, sorteio, validação de pacote, transição de inventário/coleção e recompensa diária, sem `IO`. |
| Serviços | `Service.AuthService`, `Service.CardAPI`, `Service.CardImportService`, `Service.DailyRewardService`, `Service.BoosterService`, `Service.CollectionService` | Hash/autenticação, HTTP da TCGdex, importação, transações, locks de linha, consultas e cálculos de progresso. |
| Handlers | `Handler.Home`, `Handler.Auth`, `Handler.Dashboard`, `Handler.Reward`, `Handler.Player`, `Handler.Booster`, `Handler.Collection` | Sessão, JSON de entrada/saída, códigos HTTP e coordenação de serviços; não contêm regras profundas de jogo. |
| Testes | `test/Spec.hs`, `test/Integration.hs`, `test/HttpSpec.hs` | Domínio/serviços, PostgreSQL isolado e fluxos Yesod. |

Não existe camada Repository separada. Ela só será criada se eliminar duplicação real; hoje os serviços usam Persistent diretamente.

## Fluxo de uma requisição

1. Warp recebe a requisição e o middleware CORS de `Application` aplica a política opt-in.
2. `Foundation.yesodMiddleware` aplica sessão e CSRF (`defaultCsrfMiddleware`); POSTs sem token recebem 403.
3. `isAuthorized` verifica a sessão e a existência da conta nas rotas privadas; falhas viram 401.
4. O handler lê o JSON/sessão, resolve a conta e chama `runDB`.
5. A ação `SqlPersistT` do serviço lê/escreve no PostgreSQL; as mutações de recompensa/abertura da mesma conta usam `SELECT ... FOR UPDATE` na linha `User`.
6. O domínio puro transforma o estado; em `Left`, o serviço não persiste resultado parcial.
7. O handler serializa JSON; `errorHandler` padroniza 400/401/403/404/405/500 sem vazar detalhes internos.

GETs de jogo são somente leitura. A única concessão de recompensa é `POST /rewards/daily/claim`, autenticado e protegido por CSRF, com data calculada no servidor. A abertura é `POST /boosters/open`; o cliente não escolhe cartas nem quantidade.

## Dependências e execução

O fluxo é Stack + Hpack: `package.yaml` é a fonte, `stack build` regenera o `.cabal`, e o executável/testes usam runtime threaded com `-N2`. O PostgreSQL é o único armazenamento persistente; a TCGdex é consultada apenas na importação CLI, nunca durante a abertura. A suíte SQL/HTTP usa `monadex_test_db`, com verificação de `current_database()`.

## Decisões de fronteira

- Contratos JSON são a interface com o frontend; não há Hamlet/Lucius/Julius nem tecnologia de UI imposta.
- O domínio é independente de Yesod/Persistent; os serviços fazem a tradução e a atomicidade.
- Não há JWT, CORS irrestrito, compra, aposta ou monetização.
- O histórico de aberturas é local e ordenado; `GET /boosters/last` relê sem consumir.
- Limitações atuais: sem paginação/cache de catálogo, sem teste HTTP concorrente, sem validação HTTPS real, sem retry/backoff na importação e sem OpenAPI/Swagger/Postman nesta entrega.

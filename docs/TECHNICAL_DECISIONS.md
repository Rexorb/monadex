# Decisões técnicas

## Fase 0

- Preservar `projectcontext.md` como especificação; não havia scaffold Yesod.
- Não instalar nem alterar ferramentas do sistema: GHC, Stack, Cabal e Docker Compose já estão disponíveis.
- Não utilizar a porta 5432 ocupada por outro serviço; propor 5433 configurável para o PostgreSQL do projeto, verificando novamente antes de iniciar.
- Adiar escolha de resolver Stack até confirmar compatibilidade de Yesod/Persistent com GHC e disponibilidade das dependências; não inferir compatibilidade apenas pela presença das ferramentas.
- Evitar criar camada Repository sem necessidade demonstrada.

## Fase 1

- `lts-20.26` usa GHC 9.2.8 já instalado via Stack; dependências Yesod/Persistent compilaram sem alterações globais.
- Backend somente: `GET /` retorna JSON de diagnóstico; outro dev implementará a interface.
- Modelo e rota inline em Haskell evitam cópias não sincronizadas em arquivos de configuração.
- Credencial em `.env` local ignorado pelo Git; servidor recebe `DATABASE_URL`. Compose publica o banco somente no loopback, porta 5433 por padrão.
- CHECKs SQL complementam Persistent; na Fase 1, raridade era `Text` e foi tipada como `Rarity` na Fase 3. Futuras migrations devem preservar as restrições.

## Fase 3

- `Card.rarity` foi tipado como `Rarity` em Haskell e serializado pelo Persistent; CHECK SQL protege o mesmo domínio no PostgreSQL.
- A TCGdex expõe a lista de cartas sem raridade: buscar detalhes de cada carta, validar o lote completo e só então efetuar upserts na transação do banco.
- Não inferir a espécie Pokémon apenas pelo nome de carta; campo opcional fica vazio quando a API não fornece espécie confiável.
- O executável recebe `--import-set swsh12`; a importação não ocorre em requisições de booster. `runNoLoggingT` evita logs de consultas e dados por padrão; erros do CLI continuam visíveis.

## Fase 4

- Endpoints JSON sem frontend próprio, para integração pelo outro desenvolvedor; Yesod mantém cookies de sessão e `defaultCsrfMiddleware` protege POSTs via `X-XSRF-TOKEN`.
- Hash de senha PBKDF2-HMAC-SHA256 (`cryptonite`) com salt aleatório e 210 mil iterações; não inventar algoritmo próprio.
- A chave de sessão é arquivo local ignorado pelo Git, gerado sob umask 077 e restringido a 0600 antes de aceitar requisições. Em implantação HTTPS, configurar `SESSION_COOKIE_SECURE=true` para habilitar o bit Secure.
- Limitação de tentativas persistida por username no PostgreSQL, com upsert condicional atômico; limites complementares de rede ficam pendentes para produção.

## Fase 5

- Timezone via `timezone-olson`/`timezone-series` lendo `/usr/share/zoneinfo/America/Sao_Paulo` na inicialização: evita supor UTC-3 fixo e cobre mudanças históricas; a ausência do arquivo impede iniciar em vez de usar data incorreta.
- Bloqueio `FOR UPDATE` na linha `User` é compartilhado por recompensa e abertura; combinado com transação por `runSqlPool` e unicidade do banco, evita concessões e consumos concorrentes indevidos.
- Semente obtida de `Crypto.Random.getRandomBytes` no servidor; o sorteio puro recebe `StdGen`. Não há alteração de inventário pelo frontend nem pagamento, aposta ou pressão para retorno diário.
- `BoosterOpening` e `BoosterOpeningCard` armazenam o resultado ordenado na mesma transação; `GET /boosters/last` permite reler sem nova abertura. O histórico permanece local, associado ao usuário.
- Executável e testes SQL compilados com `-threaded -with-rtsopts=-N2` depois de identificar bloqueio do runtime não threaded em requisições simultâneas.

## Revisão pré-commit 02

- GETs não devem modificar dados de jogo. `authenticatedPlayer` só resolve a sessão; o frontend pode iniciar automaticamente a concessão diária enviando `POST /rewards/daily/claim` com cookie e CSRF. POST repetido devolve HTTP 200, `claimed: true`, `grantedNow: false` e não incrementa o inventário.
- O mesmo bloqueio transacional de usuário garante idempotência e concorrência. `grantDailyRewardAt` injeta uma hora controlada exclusivamente em testes isolados; nenhuma rota aceita dia do cliente.
- `Model.migrateMonadex` aplica o mesmo esquema/constraints em app e teste: CHECK no inventário, coleção, raridade e posição do histórico. A revisão não alterou o banco de desenvolvimento; as migrations são aplicadas ao iniciar o servidor e nos testes isolados.
- `FRONTEND_ORIGIN` é opcional e aceita uma origem explícita HTTPS (ou HTTP somente em loopback local). `wai-cors` usa lista fechada e credenciais; o padrão sem CORS favorece proxy de mesma origem. CORS é política do navegador, não autenticação. O cookie de sessão continua HttpOnly e SameSite=Strict; o cookie CSRF é legível pelo cliente para envio do header. HTTPS, reconhecimento TLS e Secure devem ser validados em produção.
- `yesod-test` executa fluxos JSON, autenticação, CSRF, GET sem recompensa, POST idempotente, abertura e isolamento no banco isolado. O cliente HTTP da TCGdex aceita transporte injetado para falhas simuladas; nunca consulta o serviço real na suíte.
- `GET /dashboard`, `GET /boosters/last` e `POST /rewards/daily/claim` montam seus dados em uma única ação `runDB` por endpoint, reduzindo a intercalação entre transações. O PostgreSQL opera em READ COMMITTED por padrão, então a consistência forte das mutações de recompensa/abertura continua vindo do lock de linha; não se promete um snapshot serializável para leituras.
- Login com username inexistente verifica um hash PBKDF2 fixo e descartável, igualando o custo aproximado ao de uma senha errada; a mensagem HTTP continua genérica.

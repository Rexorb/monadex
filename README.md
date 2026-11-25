# Monadex

Monadex é um projeto acadêmico de colecionismo Pokémon TCG. O objetivo é permitir que uma conta abra boosters gratuitos, forme uma coleção e acompanhe o progresso por expansão, sem compras, apostas ou monetização.

**Escopo atual: exclusivamente backend.** A interface será desenvolvida por outra integrante do projeto. A integração ocorre por contratos HTTP/JSON documentados em `docs/BACKEND_API.md` e `docs/AUTH_API.md`; não há templates Hamlet, componentes visuais ou tecnologia de frontend imposta por este repositório.

## Stack tecnológica

- Haskell com GHC 9.2.8, resolvido pelo Stack `lts-20.26`.
- Yesod para roteamento, sessões, CSRF e handlers JSON.
- Persistent e PostgreSQL 16 para persistência.
- Hspec, `yesod-test` e `wai-extra` para testes.
- Docker Compose para o PostgreSQL local.
- TCGdex REST V2 apenas para importar o catálogo; a abertura de boosters usa o banco local.

O fluxo de build é **Stack + Hpack**: `package.yaml` é a fonte de dependências e metadados, `stack.yaml`/`stack.yaml.lock` fixam o resolver, e `stack build` regenera `monadex.cabal`. O `.cabal` gerado é ignorado e não deve ser editado nem versionado.

## Pré-requisitos

- Stack instalado.
- Docker com Docker Compose.
- Porta local configurada para o PostgreSQL livre; o padrão é `5433`, pois `5432` pode pertencer a outro projeto.
- Acesso à internet somente para importar o catálogo TCGdex.

## Configuração

Copie o exemplo e defina uma senha local exclusiva:

```bash
cp .env.example .env
```

Variáveis usadas pelo projeto:

| Variável | Uso |
| --- | --- |
| `MONADEX_DB_PASSWORD` | Senha do PostgreSQL no Compose; obrigatória no `.env`. |
| `MONADEX_DB_PORT` | Porta publicada no loopback; padrão `5433`. |
| `DATABASE_URL` | Conexão do executável com o banco da aplicação. Exportada separadamente para o processo Haskell. |
| `PORT` | Porta HTTP do backend; padrão `3000`. |
| `SESSION_KEY_PATH` | Caminho da chave de sessão; padrão `.session-key`, criado com modo `0600`. |
| `SESSION_COOKIE_SECURE` | `true` somente atrás de HTTPS corretamente configurado. |
| `FRONTEND_ORIGIN` | Origem exata opcional para CORS; sem ela, CORS fica desativado. |
| `MONADEX_TEST_DATABASE_URL` | URL do banco isolado usado pelos testes SQL/HTTP. |

Não versione `.env`, `.session-key`, `cookies.txt` nem outros arquivos com credenciais ou sessões.

## Inicialização do PostgreSQL

```bash
docker compose up -d --wait db
```

O Compose usa PostgreSQL 16, healthcheck e volume persistente. O banco fica publicado apenas no loopback. Para conferir o serviço:

```bash
docker compose ps
```

## Compilação e execução

```bash
stack build
set -a; . ./.env; set +a
export DATABASE_URL="host=127.0.0.1 port=$MONADEX_DB_PORT user=monadex password=$MONADEX_DB_PASSWORD dbname=monadex_db"
stack exec monadex
```

As migrations são aplicadas na inicialização. Em outro terminal:

```bash
curl http://127.0.0.1:3000/
```

A resposta esperada é o JSON de diagnóstico `"monadex backend online"`. O servidor não cria interface visual.

## Importação do catálogo TCGdex

Com o mesmo ambiente e `DATABASE_URL` exportada:

```bash
stack exec monadex -- --import-set swsh12
```

A importação consulta a expansão e cada carta individualmente, valida o lote e faz upsert por identificador externo. Ela pode ser repetida sem duplicar cartas. Raridades desconhecidas são contadas e ignoradas, sem virar Common por inferência. Consulte `docs/API_INTEGRATION.md` para campos, mapeamento e limitações.

## Testes

Os testes de integração PostgreSQL e HTTP exigem um banco separado. Crie-o uma única vez, se ainda não existir:

```bash
docker compose exec -T db psql -U monadex -d postgres -c 'CREATE DATABASE monadex_test_db'
```

Depois:

```bash
set -a; . ./.env; set +a
export MONADEX_TEST_DATABASE_URL="host=127.0.0.1 port=$MONADEX_DB_PORT user=monadex password=$MONADEX_DB_PASSWORD dbname=monadex_test_db"
stack test --fast
```

A suíte registrada na revisão pré-commit 02 tem **27 exemplos aprovados, 0 falhas e 0 pendências** com o banco isolado configurado; esse resultado não foi reexecutado na etapa de documentação. Sem `MONADEX_TEST_DATABASE_URL`, os exemplos SQL/HTTP ficam pendentes e não devem ser contados como aprovados. Nunca aponte os testes para `monadex_db`. Detalhes em `docs/TESTING.md`.

## Documentação técnica

- `docs/BACKEND_API.md` — as 13 rotas, contratos JSON e efeitos.
- `docs/AUTH_API.md` — cadastro, login, sessões, CSRF, CORS e exemplos HTTP.
- `docs/MONADS.md` — aplicação real de IO, Maybe, Either, StateT, Handler e SqlPersistT.
- `docs/DATABASE.md` — entidades, chaves, unicidades, CHECKs, migrations e concorrência.
- `docs/TESTING.md` — comandos, resultados e limitações dos testes.
- `docs/ARCHITECTURE.md` — organização modular e fluxo de requisições.
- `docs/BUSINESS_RULES.md` — distribuição de raridades, boosters e recompensa diária.
- `docs/API_INTEGRATION.md` — importação TCGdex e normalização de raridades.
- `docs/TECHNICAL_DECISIONS.md` — decisões e justificativas.
- `docs/ROADMAP.md` — fases e situação.
- `docs/DEVELOPMENT_LOG.md` — histórico operacional.

## Limitações conhecidas

- HTTPS real, `Secure` e reconhecimento de TLS atrás de proxy ainda não foram validados ponta a ponta.
- A concorrência crítica é testada no serviço/SQL; não há teste HTTP automatizado com requisições simultâneas.
- O throttling de login é por username, sem limite complementar por IP/rede.
- O banco `monadex_test_db` é compartilhado e não é truncado entre execuções; contas e fixtures se acumulam.
- A importação TCGdex é sequencial, não remove cartas excluídas upstream e não possui retry/backoff nem timeout total.
- Cada consulta de coleção carrega o catálogo completo; paginação/cache serão necessários em catálogos maiores.
- `SameSite=Strict` exige frontend e API no mesmo site; para sites distintos, será necessário proxy de mesmo site ou revisão da política de cookies.
- Não há frontend, OpenAPI, Swagger ou coleção Postman nesta entrega.

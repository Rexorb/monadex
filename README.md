# Monadex

Monadex é uma aplicação acadêmica de colecionismo Pokémon TCG. Permite cadastro e login, recompensa diária de um booster gratuito, abertura de boosters, consulta do histórico e gerenciamento de coleção por raridade, nome e expansão, sem compras, apostas ou monetização.

O projeto está dividido em um backend HTTP em Haskell/Yesod e uma interface React/TypeScript/Vite. Os dois componentes já são integrados por uma API JSON usando a mesma sessão em cookies.

## Funcionalidades implementadas

- Cadastro, login e logout com sessão HttpOnly.
- Proteção CSRF em operações que criam sessão ou alteram dados.
- Concessão de no máximo um booster por usuário por dia em `America/Sao_Paulo`.
- Booster com seis cartas, sorteadas no servidor a partir do catálogo PostgreSQL.
- Histórico da última abertura sem novo consumo de booster.
- Coleção com contagem de cópias, cartas únicas e filtros combináveis.
- Dashboard de progresso e resumo por raridade.
- Página de expansões e progresso por expansão.
- Interface responsiva para desktop e celular.
- Teste de fluxo E2E com Playwright.

## Stack

### Backend

- GHC 9.2.8 via Stack `lts-20.26`, com Hpack.
- Yesod para rotas, sessões, CSRF e JSON.
- Persistent e PostgreSQL 16.
- Hspec, `yesod-test`, `wai-extra` e PostgreSQL isolado para testes.
- Docker Compose para banco local.
- TCGdex REST V2 somente na importação do catálogo.

### Frontend

- React 19 e React Router.
- TypeScript.
- Vite 6.
- SCSS.
- Lucide React.
- Fetch API com cookies de sessão.
- Playwright para o fluxo E2E.

O frontend está em `frontend/`. Confira [frontend/README.md](frontend/README.md) para execução e build.

## Pré-requisitos

- Git.
- Stack para Haskell.
- Docker com Docker Compose.
- Node.js e npm para o frontend.
- PostgreSQL publicado no padrão local `127.0.0.1:5433`.
- Acesso à internet somente para importar o catálogo TCGdex.

## Configuração do backend

Na raiz de `monadex/`, copie o exemplo e defina uma senha local exclusiva:

```bash
cp .env.example .env
```

No Windows PowerShell, use:

```powershell
Copy-Item .env.example .env
```

Variáveis principais:

| Variável | Uso |
| --- | --- |
| `MONADEX_DB_PASSWORD` | Senha do PostgreSQL no Compose. |
| `MONADEX_DB_PORT` | Porta publicada no loopback; padrão `5433`. |
| `DATABASE_URL` | Conexão exportada separadamente para o executável Haskell. |
| `PORT` | Porta HTTP do backend; padrão `3000`. |
| `SESSION_KEY_PATH` | Caminho da chave de sessão; padrão `.session-key`. |
| `SESSION_COOKIE_SECURE` | `true` somente atrás de HTTPS corretamente configurado. |
| `FRONTEND_ORIGIN` | Origem exata opcional para CORS. |
| `MONADEX_TEST_DATABASE_URL` | URL exclusiva do banco usado pelos testes SQL/HTTP. |

Não versione `.env`, `.session-key`, `cookies.txt` ou qualquer arquivo com credenciais.

## Inicialização completa

1. Inicie o PostgreSQL:

```bash
docker compose up -d --wait db
```

2. Configure e exporte o ambiente do backend.

No Git Bash/Linux:

```bash
set -a
. ./.env
set +a
export DATABASE_URL="host=127.0.0.1 port=${MONADEX_DB_PORT:-5433} user=monadex password=$MONADEX_DB_PASSWORD dbname=monadex_db"
```

No Windows PowerShell:

```powershell
$env:MONADEX_DB_PASSWORD = "sua-senha-do-compose"
$env:DATABASE_URL = "host=127.0.0.1 port=5433 user=monadex password=$env:MONADEX_DB_PASSWORD dbname=monadex_db"
```

3. Compile e execute o backend:

```bash
stack build
stack exec monadex
```

As migrations são aplicadas na inicialização. Confira em outro terminal:

```bash
curl http://127.0.0.1:3000/
```

Resposta esperada: o JSON `"monadex backend online"`.

4. Em outro terminal, execute o frontend:

```bash
cd frontend
npm ci
npm run dev
```

Abra `http://127.0.0.1:5183/`. O Vite encaminha `/api/*` para o backend em `127.0.0.1:3000` e mantém a sessão na mesma origem local.

## Importar o catálogo

Com PostgreSQL ativo e `DATABASE_URL` configurada, importe uma expansão:

```bash
stack exec monadex -- --import-set swsh12
```

A importação valida o lote, normaliza raridades conhecidas e faz upsert por identificador externo. Ela pode ser repetida sem duplicar cartas. Raridades desconhecidas são ignoradas em vez de convertidas em `Common`.

## Testes do backend

Crie o banco isolado uma vez:

```bash
docker compose exec -T db psql -U monadex -d postgres -c "CREATE DATABASE monadex_test_db"
```

No Git Bash/Linux, configure `MONADEX_TEST_DATABASE_URL` antes dos testes:

```bash
export MONADEX_TEST_DATABASE_URL="host=127.0.0.1 port=${MONADEX_DB_PORT:-5433} user=monadex password=$MONADEX_DB_PASSWORD dbname=monadex_test_db"
stack test --fast
```

No banco isolado, a suíte registrada na revisão pré-commit 02 passou com **27 exemplos aprovados, 0 falhas e 0 pendências**. Esse resultado não substitui uma nova execução antes de publicar mudanças. Sem `MONADEX_TEST_DATABASE_URL`, os testes SQL/HTTP ficam pendentes.

Nunca execute os testes apontando para `monadex_db`. O banco `monadex_test_db` é compartilhado entre execuções e acumula fixtures; use um banco descartável quando necessário.

## Testes do frontend

Com backend ativo, catálogo importado e frontend em execução:

```bash
cd frontend
npx playwright install chromium
npm run test:e2e
```

O teste usa uma conta aleatória no banco apontado pelo backend e cobre registro, login/logout, recompensa, abertura de seis cartas, coleção, filtros, expansões, imagens, login inválido e layout móvel.

## Build de produção

```bash
cd frontend
npm ci
npm run build
npm run preview
```

`dist/` contém a aplicação estática. A publicação deve usar um proxy reverso de mesma origem que encaminhe `/api/*` ao backend removendo o prefixo `/api`.

## Documentação técnica

- [Contrato da API](docs/BACKEND_API.md) — 13 rotas, JSON e efeitos.
- [Autenticação](docs/AUTH_API.md) — cadastro, login, sessão, CSRF e CORS.
- [Arquitetura](docs/ARCHITECTURE.md) — organização das camadas.
- [Banco de dados](docs/DATABASE.md) — entidades, unicidades, CHECKs e concorrência.
- [Regras de negócio](docs/BUSINESS_RULES.md) — boosters, raridades e recompensa diária.
- [Integração TCGdex](docs/API_INTEGRATION.md) — importação e normalização.
- [Testes](docs/TESTING.md) — banco isolado e resultados.
- [Monads](docs/MONADS.md) — uso prático em domínio e infraestrutura.
- [Decisões técnicas](docs/TECHNICAL_DECISIONS.md) — justificativas.
- [Roadmap](docs/ROADMAP.md) — estado das fases.
- [Registro de desenvolvimento](docs/DEVELOPMENT_LOG.md) — histórico operacional.

## Limitações conhecidas

- HTTPS, cookie `Secure` e TLS atrás de proxy ainda não foram validados ponta a ponta.
- O teste automatizado crítico de concorrência cobre serviços/SQL; não há teste HTTP simultâneo.
- O throttling de login é persistido por username, sem limite complementar por IP/rede.
- A importação é sequencial, não remove cartas excluídas upstream e não tem retry/backoff ou timeout total.
- Consultas de coleção carregam o catálogo completo; catálogos muito maiores exigiriam paginação/cache.
- `SameSite=Strict` exige frontend e API no mesmo site.
- Não há OpenAPI, Swagger ou coleção Postman desta entrega.

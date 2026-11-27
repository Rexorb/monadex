# Monadex — frontend

Interface React da aplicação Monadex. Integra-se ao backend Haskell/Yesod por JSON, cookies de sessão e CSRF; não usa mocks, JWT ou armazenamento local de credenciais.

## Tecnologias

- React 19.
- React Router 7.
- TypeScript 5.
- Vite 6.
- SCSS.
- Lucide React.
- Fetch API.
- Playwright 1.65.

## Estrutura

```text
src/
  App.tsx                 rotas públicas e protegidas
  components/layout/      shell e navegação responsiva
  components/cards/       apresentação das cartas
  components/ui/          feedback e progresso
  contexts/AuthContext.tsx
                          estado da sessão
  pages/                  dashboard, boosters, coleção e expansões
  services/api.ts         cliente HTTP, CSRF e mensagens amigáveis
  styles/main.scss
  types/api.ts            tipos das respostas da API
tests/flow.spec.ts         fluxo E2E
```

## Rotas da interface

| Rota | Recurso |
| --- | --- |
| `/login` | Login |
| `/register` | Cadastro |
| `/dashboard` | Resumo da conta, cópias, cartas únicas, progresso e recompensa diária |
| `/boosters` | Quantidade disponível, última abertura e abertura de seis cartas |
| `/collection` | Catálogo e coleção com filtros de raridade, expansão e nome |
| `/expansions` | Progresso por expansão |
| `/expansions/:id` | Catálogo e cartas únicas adquiridas de uma expansão |

Rotas protegidas redirecionam visitantes para `/login`. A sessão é verificada por `GET /dashboard`; o frontend não mantém senha ou token em estado persistente.

## Pré-requisitos

- Backend Haskell em `http://127.0.0.1:3000`.
- PostgreSQL e catálogo importado.
- Node.js e npm.
- Chromium para Playwright.

## Executar em desenvolvimento

Na raiz do backend, inicie PostgreSQL e backend conforme o [README principal](../README.md). Em seguida, nesta pasta:

```bash
npm ci
npm run dev
```

Abra `http://127.0.0.1:5183/`.

O servidor Vite:

- usa host e porta fixos `127.0.0.1:5183`;
- encaminha `/api/*` ao backend;
- remove o prefixo `/api` antes do proxy;
- envia cookies com `credentials: include`.

Não misture `localhost` e `127.0.0.1`, pois a sessão usa `SameSite=Strict`.

## Configurar o backend de desenvolvimento

O alvo padrão é:

```text
http://127.0.0.1:3000
```

Para mudar a porta, copie o exemplo e ajuste a variável:

```bash
cp .env.example .env
```

```text
VITE_BACKEND_TARGET=http://127.0.0.1:3000
```

Variáveis `VITE_*` são públicas no navegador. Nunca coloque senha, cookie, chave de sessão ou segredo nelas.

O backend não precisa de CORS separado para o fluxo local com o proxy `/api`. CORS deve ser configurado somente quando frontend e backend forem hospedados em origens diferentes.

## Importar cartas reais

Da raiz do backend, com `DATABASE_URL` exportada:

```bash
stack exec monadex -- --import-set swsh12
```

A interface pode iniciar antes da importação, mas não haverá cartas suficientes para abrir boosters até o catálogo ser importado.

## Build

```bash
npm run build
npm run preview
```

`npm run build` executa `tsc -b` e gera `dist/`. `npm run preview` hospeda a build em `http://127.0.0.1:4173/`, mantendo o proxy local `/api`.

Para produção fora do Vite, hospede `dist/` em um servidor estático e configure um proxy reverso de mesma origem:

- `/api/*` -> backend Yesod;
- remova o prefixo `/api`;
- encaminhe cookies;
- use HTTPS real e valide `Secure`, `SameSite` e o proxy TLS antes da publicação.

## Fluxo de autenticação e CSRF

1. O frontend chama `GET /auth/csrf`.
2. O token retornado é mantido apenas na memória do navegador.
3. Toda requisição `POST` envia `X-XSRF-TOKEN`.
4. O cookie `_SESSION` mantém a autenticação.
5. Ao receber 403 em um POST, o cliente renova o token CSRF e tenta novamente uma vez.
6. Logout limpa o token em memória e o usuário protegido no contexto React.

## Testes E2E

Com backend, banco, catálogo e Vite em execução:

```bash
npx playwright install chromium
npm run test:e2e
```

O teste cobre:

- cadastro e login;
- logout;
- recompensa diária;
- abertura de seis cartas;
- coleção e filtro por raridade;
- imagens das cartas;
- expansão e detalhe;
- login inválido;
- navegação móvel em 390 px;
- ausência de erros inesperados no navegador.

O teste cria uma conta aleatória no banco configurado para o backend. Use um banco descartável ou isolado para não preservar registros de demonstração. Capturas descritas no teste são externas ao repositório.

## Comandos úteis

```bash
npm ci
npm run dev
npm run build
npm run preview
npm run test:e2e
```

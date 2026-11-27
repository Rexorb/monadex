# MONADEX — frontend

Aplicação React/Vite/TypeScript/SCSS integrada **ao backend Yesod existente**, sem mocks ou autenticação JWT. Usa o proxy `/api` do Vite em desenvolvimento para manter cookies de sessão e CSRF na mesma origem.

## Executar localmente

1. Na raiz do projeto, inicie o PostgreSQL (`docker compose up -d --wait db`) e o backend com `DATABASE_URL` configurada conforme o [README principal](../README.md). Confirme `curl http://127.0.0.1:3000/`.
2. Em outro terminal, na pasta `frontend/`:

   ```bash
   npm ci
   npm run dev
   ```

3. Abra **http://127.0.0.1:5183/**. Não misture `localhost` e `127.0.0.1` por causa de `SameSite=Strict`.

O alvo padrão do proxy é `http://127.0.0.1:3000`. Para mudar a porta, copie `.env.example` para `.env` nesta pasta e ajuste `VITE_BACKEND_TARGET` para a origem do backend. Não coloque senhas nem tokens em variáveis `VITE_*`, pois elas são expostas ao navegador. Com o proxy de mesma origem, `FRONTEND_ORIGIN` e CORS não precisam ser ativados no backend. O catálogo precisa estar importado para abrir boosters e visualizar cartas reais: `stack exec monadex -- --import-set swsh12` com `DATABASE_URL` no mesmo ambiente.

## Build

```bash
npm run build
npm run preview
```

`npm run build` valida TypeScript e gera `dist/`; `npm run preview` serve a build em `http://127.0.0.1:4173/` com o mesmo proxy local `/api` para demonstração. Para publicar fora do Vite, configure um proxy reverso de mesma origem que encaminhe `/api/*` ao backend removendo `/api`. HTTPS, cookies `Secure` e proxy TLS devem ser validados antes de publicar fora de desenvolvimento.

## Teste do fluxo no navegador

Com backend, catálogo real e Vite em execução:

```bash
npx playwright install chromium
npm run test:e2e
```

O teste cobre cadastro, logout/login, recompensa diária, abertura de seis cartas, histórico, coleção, filtro, imagens, expansões, login inválido e viewport de 390 px. **Ele cria contas de demonstração no banco apontado pelo backend**; use um ambiente descartável se não quiser conservar esses registros. Screenshots de desenvolvimento são gravados em `/tmp/opencode`, não no repositório.

O fluxo é: cadastro/login → dashboard → recompensa diária por POST → abertura de booster no servidor → coleção → expansões → logout. A sessão é mantida somente em cookies do Yesod; o token CSRF fica em memória e é obtido por `GET /auth/csrf`.

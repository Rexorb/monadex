# Autenticação e segurança HTTP

O backend usa sessões do Yesod com cookie `_SESSION` `HttpOnly` e `SameSite=Strict`. O token CSRF é disponibilizado no cookie `XSRF-TOKEN`, legível pelo cliente, e deve ser enviado no header `X-XSRF-TOKEN`. A chave de sessão é gerada localmente em `.session-key` (ou `SESSION_KEY_PATH`), restrita a `0600` e ignorada pelo Git. Em produção, **HTTPS e `SESSION_COOKIE_SECURE=true` são obrigatórios**; atrás de proxy TLS, confirme que a aplicação reconhece a requisição como segura antes de publicar. O bit `Secure` e o reconhecimento de TLS em proxy ainda não foram validados ponta a ponta neste projeto.

## Rotas

| Rota | Requisição | Respostas relevantes |
| --- | --- | --- |
| `GET /auth/csrf` | Sem corpo | 200 `{ "csrfToken": "..." }`; emite/renova cookies de sessão e CSRF |
| `POST /register` | Cookie + `X-XSRF-TOKEN`; `Content-Type: application/json`; JSON `{ "username": "alice", "password": "senha-ilustrativa", "confirmation": "senha-ilustrativa" }` | 201 `{ "username": "alice" }`; 400 erro de validação ou `UsernameTaken`; 403 CSRF |
| `POST /login` | Cookie + `X-XSRF-TOKEN`; `Content-Type: application/json`; JSON `{ "username": "alice", "password": "senha-ilustrativa" }` | 200 `{ "username": "alice" }`; 401 `{ "error": "Invalid credentials" }`; 403 CSRF |
| `POST /logout` | Cookie + `X-XSRF-TOKEN`; sem corpo | 200 `{ "loggedOut": true }`; 403 CSRF |
| `GET /dashboard` | Cookie de sessão | 200 resumo JSON (ver `BACKEND_API.md`); 401 `{ "error": "Authentication required" }` |

Todo POST, inclusive cadastro, login, logout e concessão diária, exige o cookie e o header `X-XSRF-TOKEN` com o token obtido em `GET /auth/csrf`. Sem token válido: **403** `{ "error": "Forbidden" }`. O Yesod também aceita o parâmetro `_token` em formulários, mas o contrato JSON usa o header.

## Regras de conta

Os exemplos de senha são apenas placeholders; nenhuma senha de produção consta neste arquivo. Username é normalizado para minúsculas, tem 3–32 caracteres ASCII (`a-z`, `0-9`, `_`) e é único no banco. Senha: 12–1024 caracteres, confirmação obrigatória. Hash PBKDF2-HMAC-SHA256 (`cryptonite`), 210.000 iterações e salt aleatório de 16 bytes; a comparação do hash é constante. Login incorreto responde genericamente e, para username inexistente, o servidor ainda executa uma derivação PBKDF2 descartável, reduzindo a diferença de tempo entre contas existentes e inexistentes.

Cinco falhas por username bloqueiam novas tentativas por 15 minutos desde a última falha; tentativas bloqueadas não prolongam o prazo. **Limitação atual:** o limite é por username, não por IP/rede; ataques distribuídos e abuso de recursos exigem complementação na implantação.

## Sessão, CSRF e CORS

- O cookie de sessão `_SESSION` é `HttpOnly` e `SameSite=Strict`; não deve ser lido por JavaScript.
- O cookie `XSRF-TOKEN` existe para o cliente obter o token; envie-o também em `X-XSRF-TOKEN`.
- `FRONTEND_ORIGIN` é opcional e aceita **uma** origem exata. Sem ela, CORS fica desativado, o que favorece proxy de mesma origem.
- Apenas HTTP de loopback (`localhost`/`127.0.0.1`) é aceito como origem de desenvolvimento; outras origens exigem HTTPS.
- CORS não substitui CSRF nem autorização. Credenciais exigem `credentials: include` no cliente.
- `SameSite=Strict` requer frontend e API no mesmo site. Em desenvolvimento, não misture `localhost` com `127.0.0.1`.
- Em produção, use HTTPS, `SESSION_COOKIE_SECURE=true` e valide o reconhecimento de TLS no proxy reverso.

## Exemplos HTTP independentes de frontend

Os comandos abaixo usam apenas `curl` e um cookie jar local. Substitua os placeholders; não use senhas reais em histórico de shell.

```bash
# 1. Obter token e cookies
curl -sS -c cookies.txt http://127.0.0.1:3000/auth/csrf

# 2. Copiar o campo csrfToken da resposta para TOKEN e cadastrar
TOKEN='<csrfToken>'
curl -sS -b cookies.txt -c cookies.txt \
  -H 'Content-Type: application/json' \
  -H "X-XSRF-TOKEN: $TOKEN" \
  -d '{"username":"alice","password":"<senha-ficticia>","confirmation":"<senha-ficticia>"}' \
  http://127.0.0.1:3000/register

# 3. Login
curl -sS -b cookies.txt -c cookies.txt \
  -H 'Content-Type: application/json' \
  -H "X-XSRF-TOKEN: $TOKEN" \
  -d '{"username":"alice","password":"<senha-ficticia>"}' \
  http://127.0.0.1:3000/login

# 4. Consultar o dashboard (GET, sem efeito de recompensa)
curl -sS -b cookies.txt http://127.0.0.1:3000/dashboard

# 5. Solicitar a recompensa elegível (POST idempotente)
curl -sS -b cookies.txt -H "X-XSRF-TOKEN: $TOKEN" \
  -X POST http://127.0.0.1:3000/rewards/daily/claim

# 6. Logout
curl -sS -b cookies.txt -H "X-XSRF-TOKEN: $TOKEN" \
  -X POST http://127.0.0.1:3000/logout
```

O cliente deve manter o cookie jar entre as requisições. Para um frontend em outra origem, configure `FRONTEND_ORIGIN` com a origem exata e envie credenciais; mantenha frontend e API no mesmo site para `SameSite=Strict`. O token CSRF não é uma credencial de login e não substitui a sessão.

As rotas privadas são autorizadas no servidor; IDs de usuários não são aceitos do frontend para acessar coleção/inventário. Requisições GET do jogo são somente leitura. A recompensa é solicitada por `POST /rewards/daily/claim`, cujo efeito é idempotente e cujo contrato está em `BACKEND_API.md`.

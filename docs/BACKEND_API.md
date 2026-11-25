# Contrato HTTP/JSON do backend

API em Yesod, sem telas, com **13 rotas** implementadas. Os endpoints públicos de autenticação estão detalhados também em `AUTH_API.md`. Respostas são JSON; em erros, `{ "error": "..." }`. Requisições POST exigem o cookie de sessão/CSRF e o header `X-XSRF-TOKEN` obtido em `GET /auth/csrf` (inclusive cadastro/login). O frontend deve usar o mesmo domínio/origem sempre que possível; para origem separada, configure **uma** `FRONTEND_ORIGIN`, envie cookies (`credentials: include`) e mantenha frontend e API no mesmo site para `SameSite=Strict`. Não há CORS irrestrito nem autenticação JWT.

Headers comuns:

- `Cookie`: cookie de sessão `_SESSION`; o token CSRF também é disponibilizado no cookie `XSRF-TOKEN`.
- `X-XSRF-TOKEN`: token CSRF em todo POST autenticado ou que crie sessão.
- `Content-Type: application/json`: obrigatório em `POST /register` e `POST /login`.
- `Origin`: necessário somente quando o frontend estiver em outra origem configurada por `FRONTEND_ORIGIN`.

## Rotas implementadas

| Método / URL | Autenticação | Headers / parâmetros / corpo | Sucesso (exemplo) | Erros típicos | Efeito no PostgreSQL |
| --- | --- | --- | --- | --- | --- |
| `GET /` | Não | Sem parâmetros | 200 `"monadex backend online"` | — | Nenhum |
| `GET /auth/csrf` | Não | Cookie de sessão, se existente | 200 `{ "csrfToken": "..." }` | — | Nenhum; pode iniciar/renovar cookie |
| `POST /register` | Não | Cookie + `X-XSRF-TOKEN`; `Content-Type: application/json`; JSON `{ "username": "alice", "password": "exemplo-de-senha", "confirmation": "exemplo-de-senha" }` | 201 `{ "username": "alice" }` | 400 `{ "error": "UsernameTaken" }`, `InvalidUsername`, `InvalidPassword`, `PasswordMismatch`; 403 CSRF | Cria conta e inventário inicial zero na mesma transação; cria sessão |
| `POST /login` | Não | Cookie + `X-XSRF-TOKEN`; `Content-Type: application/json`; JSON `{ "username": "alice", "password": "exemplo-de-senha" }` | 200 `{ "username": "alice" }` | 401 `{ "error": "Invalid credentials" }`; 403 CSRF | Atualiza contador de falhas ou limpa-o; cria sessão no sucesso |
| `POST /logout` | Não | Cookie + `X-XSRF-TOKEN`; sem corpo | 200 `{ "loggedOut": true }` | 403 CSRF | Encerra a sessão do cliente; não altera dados do jogo |
| `GET /dashboard` | Sim | Cookie | 200 `{ "username": "alice", "boosters": 0, "totalCards": 0, "uniqueCards": 0, "byRarity": {"Common": 0, "Uncommon": 0, "Rare": 0, "UltraRare": 0}, "catalogTotal": 4, "progressPercent": 0, "dailyReward": {"date": "2026-11-25", "claimed": false} }` | 401 sem sessão | **Somente leitura**, inclusive recompensa |
| `POST /rewards/daily/claim` | Sim | Cookie + `X-XSRF-TOKEN`; sem corpo; data ignorada se enviada | 200 `{ "date": "2026-11-25", "claimed": true, "grantedNow": true, "boosters": 1 }` | 401 sem sessão; 403 CSRF; 409 `{ "error": "InvalidPlayerState" }` para inventário inconsistente | Concede no máximo um booster no dia do servidor em `America/Sao_Paulo`; POST repetido/concomitante retorna **200** com `grantedNow: false`, sem novo crédito |
| `GET /boosters` | Sim | Cookie | 200 `{ "available": 1 }` | 401 sem sessão | Somente leitura |
| `POST /boosters/open` | Sim | Cookie + `X-XSRF-TOKEN`; sem corpo (quantidade/cartas não vêm do cliente) | 200 `{ "cards": [ ... seis cartas ordenadas ... ] }` | 401; 403 CSRF; 409 `{ "error": "InsufficientBoosters" }` ou outro erro de domínio | Consome um booster, incrementa cópias e grava histórico em uma transação |
| `GET /boosters/last` | Sim | Cookie | 200 `{ "cards": [] }` ou seis cartas da última abertura | 401 sem sessão | Somente leitura; não consome booster |
| `GET /collection` | Sim | Cookie; filtros opcionais `rarity=UltraRare`, `expansion=swsh12`, `name=lugia` (combináveis) | 200 `{ "totalCatalog": 4, "uniqueOwned": 0, "cards": [{ "card": { ... }, "quantity": 0, "owned": false }] }` | 401 sem sessão | Somente leitura; filtro sem correspondência retorna lista vazia e não modifica dados |
| `GET /expansions` | Sim | Cookie | 200 `{ "expansions": [{ "id": 1, "externalId": "swsh12", "name": "Silver Tempest", "logoUrl": null, "releaseDate": null, "totalCards": 4, "uniqueOwned": 0, "progressPercent": 0 }] }` | 401 sem sessão | Somente leitura |
| `GET /expansions/{id}` | Sim | Cookie; `id` numérico interno retornado em `/expansions` | 200 `{ "expansion": { ... }, "cards": [{ "card": { ... }, "quantity": 0, "owned": false }] }` | 401; 404 `{ "error": "Not found" }` | Somente leitura |

Os exemplos de números, data, username e conteúdo do catálogo acima são **ilustrativos**, não fixtures inseridas no banco da aplicação. O retorno de carta tem `externalId`, `name`, `expansionId` (ID interno), `number`, `rarity` (uma das quatro categorias), `originalRarity`, `imageUrl` e `pokemon` opcionais. `quantity=0` e `owned=false` indicam carta não adquirida. No dashboard, `totalCards` e `byRarity` contam **cópias**, enquanto `uniqueCards` conta cartas distintas; `progressPercent` usa cartas únicas e é limitado a 0–100%. Em `/collection`, `rarity` compara o nome exato da categoria, `expansion` compara o `externalId` e `name` faz busca parcial sem diferenciar maiúsculas/minúsculas. Expansões vazias têm progresso zero e filtros sem correspondência retornam `cards: []`.

## Exemplos de sucesso

`GET /auth/csrf` — 200:

```json
{ "csrfToken": "token-ilustrativo" }
```

`POST /register` — 201 e `POST /login` — 200:

```json
{ "username": "alice" }
```

`POST /rewards/daily/claim` — primeira concessão do dia — 200:

```json
{ "date": "2026-11-25", "claimed": true, "grantedNow": true, "boosters": 1 }
```

`POST /rewards/daily/claim` — repetição no mesmo dia — 200:

```json
{ "date": "2026-11-25", "claimed": true, "grantedNow": false, "boosters": 1 }
```

`GET /dashboard` — 200:

```json
{
  "username": "alice",
  "boosters": 1,
  "totalCards": 6,
  "uniqueCards": 5,
  "byRarity": { "Common": 4, "Uncommon": 1, "Rare": 1, "UltraRare": 0 },
  "catalogTotal": 215,
  "progressPercent": 2.3255813953488373,
  "dailyReward": { "date": "2026-11-25", "claimed": true }
}
```

`POST /boosters/open` retorna `{ "cards": [ ... ] }` com exatamente seis objetos de carta na ordem de abertura. Cada objeto tem o formato abaixo; `GET /boosters/last` usa o mesmo formato, com `[]` quando não há histórico.

```json
{
  "externalId": "swsh12-001",
  "name": "Venonat",
  "expansionId": 1,
  "number": "001",
  "rarity": "Common",
  "originalRarity": "Common",
  "imageUrl": "https://images.tcgdex.net/en/swsh/swsh12/001",
  "pokemon": null
}
```

`GET /collection` retorna `{ "totalCatalog": ..., "uniqueOwned": ..., "cards": [ { "card": {...}, "quantity": ..., "owned": ... } ] }`; `quantity` conta cópias e `owned` indica presença. `GET /expansions` e `GET /expansions/{id}` usam os campos de expansão descritos na tabela.

## Erros e efeitos

- `400 { "error": "Invalid request" }`: JSON malformado ou campo obrigatório ausente.
- `400 { "error": "UsernameTaken" }` ou outro erro de cadastro: validação de conta.
- `401 { "error": "Authentication required" }`: rota privada sem sessão válida.
- `401 { "error": "Invalid credentials" }`: login inválido; a mensagem não revela se o username existe.
- `403 { "error": "Forbidden" }`: CSRF ausente/inválido.
- `404 { "error": "Not found" }`: rota ou expansão inexistente.
- `405 { "error": "Method not allowed" }`: método não aceito.
- `409 { "error": "InsufficientBoosters" }`: abertura sem saldo.
- `409 { "error": "InvalidPlayerState" }`: estado persistido inconsistente na concessão diária.
- `500 { "error": "Internal server error" }`: falha interna, sem detalhes sensíveis.

GETs não concedem recompensas nem consomem boosters. `GET /auth/csrf` pode alterar apenas cookies de sessão/CSRF. A concessão diária é idempotente por dia do servidor; não existe compra, aposta, cobrança ou mecanismo de pressão para retorno diário.

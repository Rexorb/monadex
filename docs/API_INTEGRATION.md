# Integração TCGdex (Fase 3)

Fonte: [TCGdex REST V2](https://tcgdex.dev/rest), `https://api.tcgdex.net/v2/en`. A documentação informa HTTPS, requisições GET e respostas JSON; não foi identificada garantia de disponibilidade ou quota contratual. A disponibilidade foi verificada diretamente em `GET /sets/swsh12` e `GET /cards/swsh12-001` em 2026-11-24. `GET /cards/swsh12-1` retornou 404: IDs possuem zeros à esquerda. A expansão Silver Tempest (`swsh12`) contém lista de 215 referências; raridade **não** consta na listagem e exige `GET /cards/{id}` para cada carta.

`src/Service/CardAPI.hs` desserializa JSON com Aeson e usa `http-conduit` via `Network.HTTP.Simple` (timeout de resposta de 10 segundos, exceções HTTP e status diferente de 200 tratados como erro). `src/Service/CardImportService.hs` obtém o conjunto inteiro antes de iniciar as gravações, valida IDs/obrigatoriedade e cobertura das quatro categorias e faz upsert por `externalId` em uma transação Persistent. Execute `stack exec monadex -- --import-set swsh12` com `DATABASE_URL` configurada. Raridades desconhecidas ou ausentes são contadas e ignoradas, sem alterar probabilidades; se faltar qualquer categoria após filtrar, a importação falha sem gravações.

Campos: `id`, `name`, `logo` e `releaseDate` da expansão; `id`, `name`, `localId`, `rarity` e `image` da carta. `image`, `logo`, `releaseDate`, `rarity` e `category` podem estar ausentes. Na carta examinada, `category` era `Pokemon` mas não havia campo confiável com a espécie; `pokemon` fica `NULL` em vez de inferir a espécie do nome. URL de imagem é preservada como recebida (pode ser URL-base sem sufixo/resolução). O cliente deverá escolher um formato suportado pela TCGdex ao apresentar imagens; não foi implementado frontend.

## Mapeamento explícito de raridades

| Monadex | Rótulos originais aceitos (insensíveis a maiúsculas/minúsculas) |
| --- | --- |
| Common | Common |
| Uncommon | Uncommon |
| Rare | Rare, Rare Holo, Holo Rare |
| UltraRare | Ultra Rare, Secret Rare, Holo Rare V, Holo Rare VMAX, Holo Rare VSTAR, Radiant Rare, Amazing Rare |

Outros rótulos (por exemplo `Promo` e `None`) **não** são classificados como Common. O mapeamento pode ser ampliado somente após análise explícita do fornecedor. Os pesos do jogo são fictícios e independem das raridades oficiais.

Limites conhecidos: consultas sequenciais por carta tornam a importação longa; não há paginação, cache HTTP, retry/backoff nem timeout total do lote. Erros de rede/JSON cancelam a importação, permitindo repetir depois. Uma transação de banco protege o lote de gravações; a consistência sob importações concorrentes depende dos índices únicos e do comportamento do upsert. A importação não remove cartas que o fornecedor tenha excluído; cartas existentes são atualizadas apenas pelos upserts do lote importado. A confirmação operacional da importação e reimportação está registrada em `DEVELOPMENT_LOG.md`.

Na revisão pré-commit 02, `fetchWith` permite injetar transporte em testes locais: timeout simulado, HTTP 503 e JSON inválido são exercitados sem depender da disponibilidade da TCGdex. O transporte real continua fixado a `https://api.tcgdex.net/v2/en` e limita o tempo de resposta a 10 segundos. A abertura de boosters consulta apenas o catálogo PostgreSQL.

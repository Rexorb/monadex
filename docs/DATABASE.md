# Banco de dados

PostgreSQL 16 com Persistent. O esquema é declarado em `src/Model.hs` e possui **nove tabelas**: `User`, `AuthAttempt`, `Expansion`, `Card`, `Collection`, `BoosterInventory`, `DailyReward`, `BoosterOpening` e `BoosterOpeningCard`. Não há MER/DER versionado neste repositório; as relações abaixo são a fonte textual conferida contra o código.

## Entidades, chaves e restrições

| Tabela | Chave primária | Chaves estrangeiras | Unicidade | Outras restrições |
| --- | --- | --- | --- | --- |
| `User` | `id` | — | `username` | `username` e `passwordHash` obrigatórios; `createdAt` obrigatório |
| `AuthAttempt` | `id` | — (username não é FK de `User`) | `username` | `failedCount` e `lastFailedAt` obrigatórios; usado no throttling de login |
| `Expansion` | `id` | — | `externalId` | `name` obrigatório; `logoUrl` e `releaseDate` opcionais |
| `Card` | `id` | `expansionId` → `Expansion.id` | `externalId` | `name`, `number`, `rarity` obrigatórios; `pokemon`, `originalRarity` e `imageUrl` opcionais; CHECK de raridade |
| `Collection` | `id` | `userId` → `User.id`; `cardId` → `Card.id` | `(userId, cardId)` | `quantity` obrigatória; CHECK `quantity > 0` |
| `BoosterInventory` | `id` | `userId` → `User.id` | `userId` | `quantity` obrigatória; CHECK `quantity >= 0` |
| `DailyReward` | `id` | `userId` → `User.id` | `userId` | `lastClaimDate` obrigatória; no máximo uma linha por usuário |
| `BoosterOpening` | `id` | `userId` → `User.id` | — | `openedAt` obrigatório; várias aberturas por usuário são permitidas |
| `BoosterOpeningCard` | `id` | `openingId` → `BoosterOpening.id`; `cardId` → `Card.id` | `(openingId, position)` | `position` obrigatória; CHECK `position BETWEEN 1 AND 6` |

As chaves primárias são a coluna `id` gerada pelo Persistent. As referências são FKs do PostgreSQL geradas a partir dos campos `*Id`; não há `ON DELETE CASCADE` explícito, portanto a exclusão de uma linha referenciada é rejeitada pelo banco. Não existem rotas de exclusão de contas, cartas ou históricos.

`Card.rarity` é o tipo Haskell `Rarity`, serializado pelo Persistent como texto. O CHECK `card_rarity_valid` aceita somente `Common`, `Uncommon`, `Rare` e `UltraRare`; a normalização de rótulos externos ocorre antes da gravação, em `Service.CardAPI.normalizeRarity`.

### CHECKs SQL

`Model.migrateMonadex` adiciona, de forma idempotente, quatro constraints:

| Constraint | Tabela | Regra |
| --- | --- | --- |
| `collection_quantity_positive` | `Collection` | `quantity > 0` |
| `inventory_quantity_nonnegative` | `BoosterInventory` | `quantity >= 0` |
| `card_rarity_valid` | `Card` | raridade em `Common`, `Uncommon`, `Rare`, `UltraRare` |
| `opening_card_position_valid` | `BoosterOpeningCard` | `position BETWEEN 1 AND 6` |

A quantidade positiva da coleção significa que não existe linha com zero cópias; o serviço insere/incrementa apenas cartas efetivamente adquiridas. O banco **não** garante que cada abertura tenha exatamente seis linhas de carta; essa cardinalidade é responsabilidade do serviço e do domínio, que rejeitam pacotes malformados. Também não há CHECK impedindo uma data de recompensa futura; a regra de não aceitar datas do cliente é aplicada no servidor.

## Relações

- `User` 1—N `Collection` e 1—N `BoosterOpening`; `User` 1—0..1 `BoosterInventory` e 1—0..1 `DailyReward` (as unicidades por usuário garantem no máximo uma linha).
- `Expansion` 1—N `Card`.
- `Card` 1—N `Collection` e 1—N `BoosterOpeningCard`.
- `BoosterOpening` 1—N `BoosterOpeningCard`, com posições 1–6 e ordenação preservada.
- `AuthAttempt` é independente de `User`: a chave de throttling é o username normalizado, inclusive para usernames que não existem.

## Migrations

`app/Main.hs` e o banco de testes chamam `Model.migrateMonadex`:

1. `runMigration migrateAll` cria/atualiza tabelas, colunas, índices e referências declaradas no Persistent.
2. Um bloco SQL idempotente verifica `pg_constraint` e adiciona os quatro CHECKs se ainda não existirem.

As migrations são aplicadas na inicialização do servidor e antes dos testes de integração/HTTP. Não há tabela de versão de migrations nem migrations destrutivas automáticas. Mudanças que removam/renomeiem colunas exigem procedimento manual e revisão; o fluxo atual é aditivo e repetível. O mesmo esquema e os mesmos CHECKs são usados no banco da aplicação e no banco isolado de testes.

## Transações e concorrência

`Foundation.runDB` executa uma ação `SqlPersistT` no pool via `runSqlPool`. Cada serviço compõe suas leituras e escritas em **uma** ação, portanto a unidade de commit é a operação inteira:

- `registerUser`: insere `User` e `BoosterInventory`; a unicidade de `username` decide duplicatas e a transação desfaz o inventário se algo falhar.
- `openPersistedBooster`: bloqueia a linha `User` com `SELECT ... FOR UPDATE`, lê inventário/catálogo, executa o domínio puro e grava inventário, coleção, abertura e seis cartas na mesma transação.
- `grantDailyReward`: bloqueia a mesma linha `User`, lê inventário/recompensa, executa `claimDailyReward` e atualiza inventário e `DailyReward` juntos.
- `persistCatalog`: faz upsert da expansão e das cartas em uma transação; a importação via rede acontece antes de abrir a transação de escrita.

O PostgreSQL opera em **READ COMMITTED** por padrão. As mutações de recompensa/abertura concorrentes da mesma conta são serializadas pelo lock da linha `User`; as leituras não prometem um snapshot serializável. A unicidade de `(userId, cardId)` e os CHECKs são a segunda linha de defesa contra duplicatas e valores inválidos. Uma exceção SQL durante a ação provoca rollback de todas as gravações daquela ação.

## Banco de testes isolado

Os testes de integração e HTTP exigem `MONADEX_TEST_DATABASE_URL` contendo `dbname=monadex_test_db`; antes de migrations, o código confere `SELECT current_database()` e recusa qualquer outro banco. O banco é compartilhado entre execuções e **não é truncado**: contas aleatórias e fixtures `test-only-*` se acumulam, por isso algumas asserções usam `>=`. Nunca aponte a suíte para `monadex_db`. O detalhamento dos comandos e resultados está em `TESTING.md`.

## Limitações do modelo

- Não há MER/DER formal; se um for criado, deve reproduzir as nove tabelas, FKs, unicidades e CHECKs acima.
- O histórico de aberturas não tem paginação nem limite de retenção; pode crescer indefinidamente.
- O catálogo é carregado inteiro em cada consulta de coleção/abertura; não há cache nem paginação.
- O banco de testes não é limpo automaticamente; CI deve usar banco/schema efêmero ou limpeza controlada.

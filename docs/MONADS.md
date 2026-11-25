# Mônadas e abstrações funcionais no backend

Este documento descreve **o que está realmente implementado** no backend do Monadex. Os trechos foram extraídos dos módulos compilados; não há exemplos de código inventados. As explicações conceituais são didáticas, mas os blocos de código são reais. O objetivo é explicar por que cada abstração foi usada, não apenas listar nomes.

O princípio arquitetural é separar:

- regras puras de negócio em `Domain.*`;
- efeitos de persistência em `Service.*` com `SqlPersistT`;
- requisições HTTP, sessão e JSON em `Handler.*` com `Handler`;
- inicialização e efeitos externos em `app/Main.hs` com `IO`.

## Resumo de uso real

| Abstração | Usada diretamente? | Onde |
| --- | --- | --- |
| `IO` | Sim | `app/Main.hs`, `Service.AuthService`, `Service.CardAPI`, `Service.BoosterService` |
| `Maybe` | Sim | `Domain.Card.findCard`, `Domain.Rarity.drawRarity`, `Service.CardAPI.normalizeRarity` |
| `Either` | Sim | `Domain.Booster`, `Service.CardImportService`, `Service.AuthService` |
| `State` | Não diretamente | O projeto usa seu transformador `StateT` |
| `StateT` | Sim | `Domain.Booster.openBooster`, `Domain.Player.claimDailyReward` |
| `Handler` | Sim | `Handler.Home`, `Handler.Auth`, `Handler.Reward`, `Handler.Player` |
| `SqlPersistT` | Sim | `Service.BoosterService`, `Service.DailyRewardService`, `Service.AuthService` |
| Funções puras | Sim | `Domain.*`, `Service.CollectionService.progressPercent` |
| Tipos algébricos | Sim | `Rarity`, `GameError`, `PlayerState`, `ImportError`, `RegistrationError` |
| Composição | Sim | `localDay`, `drawBooster`, `prepareCatalog`, pipelines de serviço |
| Pattern matching | Sim | `case`/guardas em domínio, serviços e handlers |

## IO

**Conceito.** `IO a` representa uma computação que pode interagir com o mundo e produzir `a`. O tipo torna o efeito explícito; funções puras não podem executá-lo sem serem elevadas a `IO`.

**Aplicação no Monadex.** `IO` fica nas bordas: inicialização do servidor, leitura de ambiente, hash de senha, relógio, aleatoriedade e HTTP da TCGdex. As regras de sorteio, abertura e recompensa não fazem `IO`.

**Módulos e assinaturas reais.**

```haskell
-- app/Main.hs
main :: IO ()

-- src/Service/AuthService.hs
hashPassword :: Text -> IO Text

-- src/Service/CardAPI.hs
fetchSet :: Text -> IO (Either ImportError ApiSet)
```

Trecho real de `app/Main.hs`:

```haskell
main :: IO ()
main = do
    _ <- setFileCreationMask 0o077
    args <- getArgs
    connection <- lookupEnv "DATABASE_URL"
    portText <- lookupEnv "PORT"
```

**Justificativa.** O domínio permanece testável e determinístico; efeitos externos são concentrados e podem ser substituídos em testes (por exemplo, `fetchWith` injeta transporte).

## Maybe

**Conceito.** `Maybe a` representa ausência explícita (`Nothing`) ou presença (`Just a`), evitando valores nulos implícitos e funções parciais como `fromJust`.

**Aplicação no Monadex.** Ausência de carta no catálogo, rótulo de raridade desconhecido e conta inexistente são modelados com `Maybe`.

**Módulos e assinaturas reais.**

```haskell
-- src/Domain/Card.hs
findCard :: CardId -> CardPool -> Maybe Card
findCard = Map.lookup

-- src/Service/CardAPI.hs
normalizeRarity :: Text -> Maybe Rarity

-- src/Service/DailyRewardService.hs
dailyRewardStatus :: MonadIO m => TimeZoneSeries -> UserId -> SqlPersistT m (Day, Bool)
```

Trecho real de `dailyRewardStatus`:

```haskell
dailyRewardStatus zone userId = do
    today <- localDay zone <$> liftIO getCurrentTime
    reward <- getBy (UniqueRewardUser userId)
    pure (today, maybe False ((>= today) . dailyRewardLastClaimDate . entityVal) reward)
```

**Justificativa.** `findCard` não lança exceção nem usa `fromJust`; `normalizeRarity` não transforma silenciosamente um rótulo desconhecido em `Common`. A ausência é tratada pelo chamador.

## Either

**Conceito.** `Either e a` representa um resultado que é erro tipado (`Left e`) ou sucesso (`Right a`). É adequado para regras de negócio que devem interromper a computação sem efeitos colaterais.

**Aplicação no Monadex.** Erros de domínio (`GameError`), importação (`ImportError`) e cadastro (`RegistrationError`) são tipos explícitos. `Either` aparece no retorno de sorteios, validação de catálogo e registro.

**Módulos e assinaturas reais.**

```haskell
-- src/Domain/Booster.hs
drawBooster :: BoosterConfig -> CardPool -> StdGen -> Either GameError ([CardId], StdGen)

-- src/Service/CardImportService.hs
prepareCatalog :: ApiSet -> [ApiCard] -> Either ImportError ([(ApiCard, Rarity)], ImportReport)

-- src/Service/AuthService.hs
validateRegistration :: Text -> Text -> Text -> Either RegistrationError Text
```

Trecho real de `drawBooster`:

```haskell
drawBooster config pool generator = do
    validateWeights config
    mapM_ (\rarity -> if any ((== rarity) . cardRarity) (Map.elems pool)
                       then Right () else Left (EmptyCardPool rarity)) [Common .. UltraRare]
    foldM pick ([], generator) (replicate 5 (regularWeights config) ++ [finalWeights config])
```

**Justificativa.** O `do` de `Either` interrompe no primeiro `Left`; não há pacote parcial nem estado atualizado quando a validação falha. O chamador decide como traduzir o erro para HTTP.

## State e StateT

**Conceito.** `State s a` é uma computação pura que lê e atualiza um estado `s` e produz `a`. `StateT s m a` é o transformador correspondente, com efeitos adicionais de `m`. Quando `m = Either e`, a computação combina estado e falha tipada: um `Left` descarta o estado atualizado.

**Aplicação no Monadex.** O projeto **não usa `State` diretamente**; usa `StateT PlayerState (Either GameError)`. Isso permite modelar a transição de inventário/coleção e interrompê-la com erro de negócio.

**Módulos e assinaturas reais.**

```haskell
-- src/Domain/Player.hs
claimDailyReward :: Day -> StateT PlayerState (Either GameError) ()

-- src/Domain/Booster.hs
openBooster :: CardPool -> [CardId] -> StateT PlayerState (Either GameError) [CardId]
```

Trecho real de `claimDailyReward`:

```haskell
claimDailyReward today = do
    player <- get
    if boosterCount player < 0 || any (<= 0) (Map.elems (collection player))
        then stateTFailure InvalidPlayerState
        else case lastClaim player of
            Just previous | previous >= today -> stateTFailure DailyRewardAlreadyClaimed
            _ -> put player { boosterCount = boosterCount player + 1, lastClaim = Just today }
```

Uso real em `Service.DailyRewardService`:

```haskell
case runStateT (claimDailyReward today) state of
    Left DailyRewardAlreadyClaimed -> pure (Right (today, False))
    Left failure -> pure (Left failure)
    Right ((), updated) -> do
        update inventoryId [BoosterInventoryQuantity =. boosterCount updated]
```

**Justificativa.** A transição é pura e testável; o serviço só persiste quando `runStateT` retorna `Right`. O estado anterior não é perdido em caso de falha.

## Handler

**Conceito.** `Handler` é a mônada de requisição do Yesod. Ela dá acesso a sessão, parâmetros, corpo JSON, respostas e ao site `App`; não deve conter regras de negócio profundas.

**Aplicação no Monadex.** Handlers resolvem a conta autenticada, chamam `runDB` e formatam JSON. `Handler.Player.authenticatedPlayer` é somente leitura; a concessão diária fica em `Handler.Reward`.

**Módulos e assinaturas reais.**

```haskell
-- src/Handler/Home.hs
getHomeR :: Handler TypedContent

-- src/Handler/Player.hs
authenticatedPlayer :: Handler (Entity User)

-- src/Handler/Reward.hs
postClaimDailyRewardR :: Handler Value
```

Trecho real de `Handler.Player`:

```haskell
authenticatedPlayer = do
    sessionName <- lookupSession "username"
    case sessionName of
        Nothing -> notAuthenticated
        Just username -> do
            found <- runDB (getBy (UniqueUsername username))
            case found of
                Nothing -> notAuthenticated
                Just player -> pure player
```

**Justificativa.** O handler traduz sessão em conta e delega a regra ao serviço. GETs não alteram inventário; a operação de escrita é explícita no POST.

## SqlPersistT

**Conceito.** `SqlPersistT m a` é a mônada de ações Persistent sobre um backend SQL, executada em um pool. Ela permite compor consultas, inserções e updates mantendo o acesso ao banco explícito no tipo.

**Aplicação no Monadex.** Serviços usam `SqlPersistT` para bloqueio de linha, leitura de inventário, upsert de coleção e histórico. `Foundation.runDB` executa a ação no pool do Yesod.

**Módulos e assinaturas reais.**

```haskell
-- src/Service/BoosterService.hs
openPersistedBooster :: MonadIO m => UserId -> SqlPersistT m (Either GameError [Entity Card])

-- src/Service/DailyRewardService.hs
grantDailyReward :: MonadIO m => TimeZoneSeries -> UserId -> SqlPersistT m (Either GameError (Day, Bool))

-- src/Model.hs
migrateMonadex :: MonadIO m => SqlPersistT m ()
```

Trecho real de `runDB`:

```haskell
instance YesodPersist App where
    type YesodPersistBackend App = SqlBackend
    runDB action = do
        pool <- appPool <$> getYesod
        runSqlPool action pool
```

**Justificativa.** A ação inteira de abertura/recompensa é uma composição `SqlPersistT`; `runDB`/`runSqlPool` delimita a transação. O bloqueio `SELECT ... FOR UPDATE` é parte da ação, não um efeito externo separado.

## Funções puras

**Conceito.** Funções puras dependem apenas dos argumentos e não produzem efeitos; o mesmo input produz o mesmo output.

**Aplicação no Monadex.** Sorteio, validação de pesos, transição de estado, cálculo de progresso e normalização de raridade são puros.

**Assinaturas reais.**

```haskell
drawRarity :: Weights -> Int -> Maybe Rarity
drawBooster :: BoosterConfig -> CardPool -> StdGen -> Either GameError ([CardId], StdGen)
openBooster :: CardPool -> [CardId] -> StateT PlayerState (Either GameError) [CardId]
progressPercent :: Int -> Int -> Double
```

Trecho real de `progressPercent`:

```haskell
progressPercent :: Int -> Int -> Double
progressPercent owned total
    | total <= 0 = 0
    | otherwise = 100 * fromIntegral (max 0 (min total owned)) / fromIntegral total
```

**Justificativa.** As regras podem ser testadas com seeds fixas e estados construídos manualmente, sem banco ou servidor. O `StdGen` explícito em `drawBooster` evita aleatoriedade escondida.

## Tipos algébricos

**Conceito.** Tipos algébricos enumeram alternativas e campos, permitindo que o compilador verifique padrões e reduza estados inválidos.

**Aplicação no Monadex.** `Rarity` tem quatro construtores; `GameError` enumera falhas; `PlayerState` agrupa inventário, coleção e última recompensa; `ImportError` e `RegistrationError` modelam falhas específicas.

**Trechos reais.**

```haskell
data Rarity = Common | Uncommon | Rare | UltraRare
    deriving (Show, Read, Eq, Ord, Enum, Bounded)

data GameError
    = InsufficientBoosters
    | DailyRewardAlreadyClaimed
    | EmptyCardPool Rarity
    | CardNotFound
    | InvalidBooster
    | InvalidPlayerState
    | InvalidWeights
    deriving (Show, Eq)
```

```haskell
data PlayerState = PlayerState
    { boosterCount :: Int
    , collection :: Map CardId Int
    , lastClaim :: Maybe Day
    } deriving (Show, Eq)
```

**Justificativa.** O pattern matching em `openBooster` e `claimDailyReward` cobre as alternativas; erros não são strings soltas. `Maybe Day` em `lastClaim` representa “nunca reivindicado” sem data sentinela.

## Composição

**Conceito.** Composição encadeia funções pequenas para construir comportamento maior, mantendo cada etapa compreensível e testável.

**Aplicação no Monadex.** `localDay` compõe conversão UTC e extração do dia local; `drawBooster` compõe validação e `foldM`; `importSet` compõe `traverse` das cartas; `prepareCatalog` compõe validação e `foldM`; serviços compõem leitura, transição e persistência.

**Trecho real.**

```haskell
localDay :: TimeZoneSeries -> UTCTime -> Day
localDay zone = LocalTime.localDay . utcToLocalTime' zone
```

```haskell
foldM pick ([], generator) (replicate 5 (regularWeights config) ++ [finalWeights config])
```

**Justificativa.** A composição mantém o fuso isolado em uma função e o sorteio em outra; o pipeline de serviço pode ser lido como “carregar estado → transição pura → persistir”.

## Pattern matching

**Conceito.** Pattern matching inspeciona construtores e extrai campos; com tipos algébricos, o compilador alerta sobre casos não cobertos quando aplicável.

**Aplicação no Monadex.** `Maybe`, `Either`, entidades Persistent e listas são tratados por `case`, guardas e compreensões.

**Trechos reais.**

```haskell
case inventory of
    Nothing -> pure (Left InvalidPlayerState)
    Just (Entity inventoryId stored) -> do
        let lastDate = dailyRewardLastClaimDate . entityVal <$> reward
            state = PlayerState (boosterInventoryQuantity stored) Map.empty lastDate
        case runStateT (claimDailyReward today) state of
            Left DailyRewardAlreadyClaimed -> pure (Right (today, False))
            Left failure -> pure (Left failure)
            Right ((), updated) -> do
                update inventoryId [BoosterInventoryQuantity =. boosterCount updated]
```

```haskell
case drawBooster standardConfig pool generator of
    Left failure -> pure (Left failure)
    Right (ids, _) -> case runStateT (openBooster pool ids) player of
        Left failure -> pure (Left failure)
        Right (_, nextState) -> case traverse (`Map.lookup` byExternal) ids of
            Nothing -> pure (Left CardNotFound)
            Just selected -> do
                update inventoryId [BoosterInventoryQuantity =. boosterCount nextState]
```

**Justificativa.** Não há `fromJust`, `head` ou `unsafePerformIO` nos módulos de produção. Casos ausentes são representados por `Nothing`/`Left` e tratados explicitamente.

## O que não é usado

Para evitar afirmações acadêmicas falsas:

- `State` puro não é importado diretamente; o projeto usa `StateT PlayerState (Either GameError)`.
- Não há `ExceptT`, `ReaderT` próprio, `WriterT` ou transformadores customizados.
- `Handler` e `SqlPersistT` são mônadas fornecidas pelas bibliotecas, não implementações didáticas do projeto.
- `IO` não é usado dentro das funções puras de `Domain.*`.
- Este documento não mistura exemplos inventados com o código: todos os blocos de código acima são citações reais dos módulos compilados. As explicações conceituais são didáticas, mas não são apresentadas como implementação existente.

## Fluxo resumido de uma abertura

1. `Handler.Booster.postOpenBoosterR` resolve a conta com `Handler`.
2. Chama `runDB (openPersistedBooster userId)`; a ação é `SqlPersistT`.
3. O serviço bloqueia a linha `User`, lê inventário e catálogo, gera seed em `IO`.
4. `drawBooster` retorna `Either GameError ([CardId], StdGen)`.
5. `runStateT (openBooster ...)` retorna `Either GameError (_, PlayerState)`.
6. Em `Right`, o serviço atualiza inventário, coleção e histórico na mesma transação.
7. O handler formata `{ "cards": [...] }` em JSON.

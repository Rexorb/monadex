{-# LANGUAGE OverloadedStrings #-}
module Service.CardImportService
    ( ImportReport(..), prepareCatalog, importSet, persistCatalog ) where

import Control.Monad (foldM)
import Control.Monad.IO.Class (MonadIO)
import Data.Char (isAsciiLower, isDigit)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T
import Database.Persist (Entity(..), (=.), upsertBy)
import Database.Persist.Sql (SqlPersistT)
import Domain.Rarity (Rarity(..))
import Model
import Service.CardAPI

data ImportReport = ImportReport
    { importedCards :: Int
    , skippedRarities :: Map.Map Text Int
    } deriving (Show, Eq)

-- Validate everything before opening a write transaction; never invent a rarity.
prepareCatalog :: ApiSet -> [ApiCard] -> Either ImportError ([(ApiCard, Rarity)], ImportReport)
prepareCatalog expansion cards = do
    if T.null (setId expansion) || T.null (setName expansion)
       || length cards /= length (setCards expansion)
       || length (Map.fromList [(apiCardId c, ()) | c <- cards]) /= length cards
        then Left (InvalidResponse "Incomplete, duplicate or invalid expansion data")
        else pure ()
    (accepted, unknown) <- foldM validate ([], Map.empty) (zip (setCards expansion) cards)
    let rarities = map snd accepted
    case filter (`notElem` rarities) [Common .. UltraRare] of
        missing:_ -> Left (IncompleteCatalog missing)
        [] -> Right (reverse accepted, ImportReport (length accepted) unknown)
  where
    validate (accepted, unknown) (summary, card)
        | summaryId summary /= apiCardId card
          || not ((setId expansion <> "-") `T.isPrefixOf` apiCardId card)
          || any T.null [apiCardId card, apiCardName card, apiCardNumber card] =
            Left (InvalidResponse "Card identifier or required field mismatch")
        | otherwise = case apiCardRarity card >>= normalizeRarity of
            Nothing -> Right (accepted, Map.insertWith (+) (maybe "<missing>" id (apiCardRarity card)) 1 unknown)
            Just rarity -> Right ((card, rarity):accepted, unknown)

-- One Persistent transaction; unique external identifiers make repeated imports idempotent.
persistCatalog :: MonadIO m => ApiSet -> [(ApiCard, Rarity)] -> SqlPersistT m ()
persistCatalog expansion cards = do
    Entity expansionKey _ <- upsertBy (UniqueExpansionExternal (setId expansion))
        (Expansion (setId expansion) (setName expansion) (setLogo expansion) (setReleaseDate expansion))
        [ExpansionName =. setName expansion, ExpansionLogoUrl =. setLogo expansion,
         ExpansionReleaseDate =. setReleaseDate expansion]
    mapM_ (storeCard expansionKey) cards
  where
    storeCard :: MonadIO m => ExpansionId -> (ApiCard, Rarity) -> SqlPersistT m ()
    storeCard expansionKey (card, rarity) = do
        let original = apiCardRarity card
            cardRecord = Card (apiCardId card) expansionKey (apiCardName card) Nothing
                              original rarity (apiCardNumber card) (apiCardImage card)
        _ <- upsertBy (UniqueCardExternal (apiCardId card)) cardRecord
            [ CardExpansionId =. expansionKey, CardName =. apiCardName card
            , CardPokemon =. Nothing, CardOriginalRarity =. original
            , CardRarity =. rarity, CardNumber =. apiCardNumber card
            , CardImageUrl =. apiCardImage card ]
        pure ()

-- HTTPS requests precede any DB writes; the caller runs persistCatalog with runSqlPool.
importSet :: Text -> IO (Either ImportError (ApiSet, [(ApiCard, Rarity)], ImportReport))
importSet identifier
    | T.null identifier || T.any (\c -> not (isAsciiLower c || isDigit c || c == '-')) identifier =
        pure (Left (InvalidResponse "Invalid set identifier"))
    | otherwise = do
        setResult <- fetchSet identifier
        case setResult of
            Left failure -> pure (Left failure)
            Right expansion
                | setId expansion /= identifier -> pure (Left (InvalidResponse "Set identifier mismatch"))
                | otherwise -> do
                    cardsResult <- traverse (fetchCard . summaryId) (setCards expansion)
                    pure $ do
                        cards <- sequence cardsResult
                        (accepted, report) <- prepareCatalog expansion cards
                        Right (expansion, accepted, report)

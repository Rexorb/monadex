{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE OverloadedStrings #-}
module Service.BoosterService (openPersistedBooster) where

import Control.Monad.IO.Class (MonadIO, liftIO)
import Control.Monad.State.Strict (runStateT)
import Crypto.Random (getRandomBytes)
import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import Data.Int (Int64)
import Data.Time (getCurrentTime)
import qualified Data.Map.Strict as Map
import Database.Persist (Entity(..), getBy, insert, selectList, update, upsertBy,
    (=.), (+=.), (==.))
import Database.Persist.Sql (SqlPersistT, Single(..), rawSql, toPersistValue)
import Domain.Booster (drawBooster, openBooster, standardConfig)
import qualified Domain.Card as Domain
import Domain.Error (GameError(..))
import Domain.Player (PlayerState(..))
import Model
import System.Random (mkStdGen)

-- The caller executes this entire action in one runDB transaction.
-- The row lock is shared with the daily reward, serializing same-user mutations.
openPersistedBooster :: MonadIO m => UserId -> SqlPersistT m (Either GameError [Entity Card])
openPersistedBooster userId = do
    _locks :: [Single Int64] <- rawSql "SELECT id FROM \"user\" WHERE id = ? FOR UPDATE"
        [toPersistValue userId]
    inventory <- getBy (UniqueInventoryUser userId)
    case inventory of
        Nothing -> pure (Left InvalidPlayerState)
        Just (Entity inventoryId stored)
            | boosterInventoryQuantity stored <= 0 -> pure (Left InsufficientBoosters)
            | otherwise -> do
                allCards <- selectList [] []
                owned <- selectList [CollectionUserId ==. userId] []
                let pool = Map.fromList
                        [(Domain.CardId (cardExternalId card), Domain.Card
                            (Domain.CardId (cardExternalId card)) (cardRarity card))
                         | Entity _ card <- allCards]
                    byExternal = Map.fromList
                        [(Domain.CardId (cardExternalId card), entity)
                         | entity@(Entity _ card) <- allCards]
                    byKey = Map.fromList [(key, card) | Entity key card <- allCards]
                    copies = Map.fromList
                        [(Domain.CardId (cardExternalId card), collectionQuantity entry)
                         | Entity _ entry <- owned
                         , Just card <- [Map.lookup (collectionCardId entry) byKey]]
                    player = PlayerState (boosterInventoryQuantity stored) copies Nothing
                seed <- liftIO (getRandomBytes 32 :: IO ByteString)
                let generator = mkStdGen (BS.foldl' (\n b -> n * 257 + fromIntegral b) 0 seed)
                case drawBooster standardConfig pool generator of
                    Left failure -> pure (Left failure)
                    Right (ids, _) -> case runStateT (openBooster pool ids) player of
                        Left failure -> pure (Left failure)
                        Right (_, nextState) -> case traverse (`Map.lookup` byExternal) ids of
                            Nothing -> pure (Left CardNotFound)
                            Just selected -> do
                                update inventoryId [BoosterInventoryQuantity =. boosterCount nextState]
                                let quantities = Map.fromListWith (+)
                                        [(entityKey entity, 1 :: Int) | entity <- selected]
                                mapM_ (\(key, count) -> do
                                    _ <- upsertBy (UniqueCollection userId key)
                                        (Collection userId key count) [CollectionQuantity +=. count]
                                    pure ()) (Map.toList quantities)
                                now <- liftIO getCurrentTime
                                openingId <- insert (BoosterOpening userId now)
                                mapM_ (\(position, entity) -> do
                                    _ <- insert (BoosterOpeningCard openingId (entityKey entity) position)
                                    pure ()) (zip [1..] selected)
                                pure (Right selected)

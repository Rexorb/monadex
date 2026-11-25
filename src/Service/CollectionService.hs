module Service.CollectionService
    ( CollectionSnapshot(..), loadCollection, progressPercent, uniqueInExpansion ) where

import Control.Monad.IO.Class (MonadIO)
import qualified Data.Map.Strict as Map
import Database.Persist (Entity(..), selectList, (==.))
import Database.Persist.Sql (SqlPersistT)
import Model

data CollectionSnapshot = CollectionSnapshot
    { catalogCards :: [Entity Card]
    , catalogExpansions :: [Entity Expansion]
    , ownedQuantities :: Map.Map CardId Int
    }

loadCollection :: MonadIO m => UserId -> SqlPersistT m CollectionSnapshot
loadCollection userId = do
    cards <- selectList [] []
    expansions <- selectList [] []
    owned <- selectList [CollectionUserId ==. userId] []
    pure (CollectionSnapshot cards expansions (Map.fromList
        [(collectionCardId c, collectionQuantity c) | Entity _ c <- owned]))

progressPercent :: Int -> Int -> Double
progressPercent owned total
    | total <= 0 = 0
    | otherwise = 100 * fromIntegral (max 0 (min total owned)) / fromIntegral total

uniqueInExpansion :: CollectionSnapshot -> ExpansionId -> Int
uniqueInExpansion snapshot expansionId = length
    [() | Entity key card <- catalogCards snapshot
        , cardExpansionId card == expansionId
        , Map.member key (ownedQuantities snapshot)]

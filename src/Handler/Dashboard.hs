{-# LANGUAGE OverloadedStrings #-}
module Handler.Dashboard (getDashboardR) where

import Data.Aeson (Value, object, (.=))
import qualified Data.Map.Strict as Map
import Database.Persist (Entity(..), getBy)
import Domain.Rarity (Rarity(..))
import Foundation
import Handler.Player (authenticatedPlayer)
import Model
import Service.CollectionService
import Service.DailyRewardService (dailyRewardStatus)
import Yesod.Core (getYesod)
import Yesod.Persist (YesodPersist(..))

getDashboardR :: Handler Value
getDashboardR = do
    Entity userId user <- authenticatedPlayer
    zone <- appTimeZone <$> getYesod
    ((today, claimed), inventory, snapshot) <- runDB $ do
        status <- dailyRewardStatus zone userId
        stored <- getBy (UniqueInventoryUser userId)
        collectionSnapshot <- loadCollection userId
        pure (status, stored, collectionSnapshot)
    let copies = ownedQuantities snapshot
        counts = [(show rarity, sum [Map.findWithDefault 0 key copies
                         | Entity key card <- catalogCards snapshot, cardRarity card == rarity])
                 | rarity <- [Common .. UltraRare]]
        total = length (catalogCards snapshot)
        unique = Map.size copies
    pure (object ["username" .= userUsername user
                 , "boosters" .= maybe 0 (boosterInventoryQuantity . entityVal) inventory
                 , "totalCards" .= sum (Map.elems copies)
                 , "uniqueCards" .= unique
                 , "byRarity" .= Map.fromList counts
                 , "catalogTotal" .= total
                 , "progressPercent" .= progressPercent unique total
                 , "dailyReward" .= object ["date" .= today, "claimed" .= claimed]])

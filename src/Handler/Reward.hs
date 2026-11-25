{-# LANGUAGE OverloadedStrings #-}
module Handler.Reward (postClaimDailyRewardR) where

import Data.Aeson (Value, object, (.=))
import Database.Persist (Entity(..), getBy)
import Foundation
import Handler.Player (authenticatedPlayer)
import Model
import Network.HTTP.Types.Status (status409)
import Service.DailyRewardService (grantDailyReward)
import Yesod.Core (getYesod, sendResponseStatus)
import Yesod.Persist (YesodPersist(..))

-- Calling this route repeatedly returns success but grants at most once per day.
postClaimDailyRewardR :: Handler Value
postClaimDailyRewardR = do
    Entity userId _ <- authenticatedPlayer
    zone <- appTimeZone <$> getYesod
    (result, inventory) <- runDB $ do
        granted <- grantDailyReward zone userId
        stored <- getBy (UniqueInventoryUser userId)
        pure (granted, stored)
    case result of
        Left failure -> sendResponseStatus status409 (object ["error" .= show failure])
        Right (today, granted) ->
            pure (object ["date" .= today, "claimed" .= True, "grantedNow" .= granted
                         , "boosters" .= maybe 0 (boosterInventoryQuantity . entityVal) inventory])

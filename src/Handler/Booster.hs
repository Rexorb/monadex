{-# LANGUAGE OverloadedStrings #-}
module Handler.Booster (getBoosterR, postOpenBoosterR, getLastOpeningR, cardJson) where

import Data.Aeson (Value, object, (.=))
import Database.Persist (Entity(..), get, getBy, selectFirst, selectList, (==.), SelectOpt(..))
import Data.Maybe (catMaybes)
import Domain.Error (GameError)
import Foundation
import Handler.Player (authenticatedPlayer)
import Model
import Network.HTTP.Types.Status (status409)
import Service.BoosterService (openPersistedBooster)
import Yesod.Core (sendResponseStatus)
import Yesod.Persist (YesodPersist(..))

getBoosterR :: Handler Value
getBoosterR = do
    Entity userId _ <- authenticatedPlayer
    available <- runDB (getBy (UniqueInventoryUser userId))
    pure (object ["available" .= maybe 0 (boosterInventoryQuantity . entityVal) available])

postOpenBoosterR :: Handler Value
postOpenBoosterR = do
    Entity userId _ <- authenticatedPlayer
    result <- runDB (openPersistedBooster userId)
    case result of
        Left failure -> sendResponseStatus status409 (object ["error" .= show (failure :: GameError)])
        Right selected -> pure (object ["cards" .= map cardJson selected])

-- Result already fixed in the database; reading it never consumes another booster.
getLastOpeningR :: Handler Value
getLastOpeningR = do
    Entity userId _ <- authenticatedPlayer
    -- One transaction: the opening is selected once and its stored cards are read together.
    stored <- runDB $ do
        opening <- selectFirst [BoosterOpeningUserId ==. userId]
            [Desc BoosterOpeningOpenedAt, Desc BoosterOpeningId]
        case opening of
            Nothing -> pure []
            Just (Entity openingId _) -> do
                items <- selectList [BoosterOpeningCardOpeningId ==. openingId]
                    [Asc BoosterOpeningCardPosition]
                cards <- mapM (get . boosterOpeningCardCardId . entityVal) items
                pure (zipWith (\entry card ->
                        Entity (boosterOpeningCardCardId (entityVal entry)) <$> card) items cards)
    pure (object ["cards" .= map cardJson (catMaybes stored)])

cardJson :: Entity Card -> Value
cardJson (Entity _ card) = object
    [ "externalId" .= cardExternalId card, "name" .= cardName card
    , "expansionId" .= cardExpansionId card, "number" .= cardNumber card
    , "rarity" .= show (cardRarity card), "originalRarity" .= cardOriginalRarity card
    , "imageUrl" .= cardImageUrl card, "pokemon" .= cardPokemon card ]

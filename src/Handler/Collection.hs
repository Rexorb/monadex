{-# LANGUAGE OverloadedStrings #-}
module Handler.Collection (getCollectionR, getExpansionsR, getExpansionDetailR) where

import Data.Aeson (Value, object, (.=))
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import Database.Persist (Entity(..), get)
import Foundation
import Handler.Booster (cardJson)
import Handler.Player (authenticatedPlayer)
import Model
import Service.CollectionService
import Yesod.Core (lookupGetParam, notFound)
import Yesod.Persist (YesodPersist(..))

getCollectionR :: Handler Value
getCollectionR = do
    Entity userId _ <- authenticatedPlayer
    rarity <- lookupGetParam "rarity"
    expansion <- lookupGetParam "expansion"
    search <- lookupGetParam "name"
    snapshot <- runDB (loadCollection userId)
    let expansionIds = Map.fromList
            [(entityKey entity, expansionExternalId (entityVal entity))
             | entity <- catalogExpansions snapshot]
        matches (Entity _ card) =
            maybe True (== T.pack (show (cardRarity card))) rarity
            && maybe True (\requested -> Map.lookup (cardExpansionId card) expansionIds == Just requested) expansion
            && maybe True (\term -> T.toCaseFold term `T.isInfixOf` T.toCaseFold (cardName card)) search
        visible = filter matches (catalogCards snapshot)
    pure (object ["totalCatalog" .= length (catalogCards snapshot)
                 , "uniqueOwned" .= Map.size (ownedQuantities snapshot)
                 , "cards" .= map (ownedCardJson snapshot) visible])

ownedCardJson :: CollectionSnapshot -> Entity Card -> Value
ownedCardJson snapshot entity@(Entity key _) = object
    ["card" .= cardJson entity
    ,"quantity" .= Map.findWithDefault 0 key (ownedQuantities snapshot)
    ,"owned" .= Map.member key (ownedQuantities snapshot)]

getExpansionsR :: Handler Value
getExpansionsR = do
    Entity userId _ <- authenticatedPlayer
    snapshot <- runDB (loadCollection userId)
    pure (object ["expansions" .= map (expansionJson snapshot) (catalogExpansions snapshot)])

expansionJson :: CollectionSnapshot -> Entity Expansion -> Value
expansionJson snapshot (Entity key expansion) =
    let total = length [() | Entity _ card <- catalogCards snapshot, cardExpansionId card == key]
        owned = uniqueInExpansion snapshot key
    in object ["id" .= key, "externalId" .= expansionExternalId expansion
              , "name" .= expansionName expansion, "logoUrl" .= expansionLogoUrl expansion
              , "releaseDate" .= expansionReleaseDate expansion
              , "totalCards" .= total, "uniqueOwned" .= owned
              , "progressPercent" .= progressPercent owned total]

getExpansionDetailR :: ExpansionId -> Handler Value
getExpansionDetailR expansionId = do
    Entity userId _ <- authenticatedPlayer
    expansion <- runDB (get expansionId)
    case expansion of
        Nothing -> notFound
        Just found -> do
            snapshot <- runDB (loadCollection userId)
            let cards = filter ((== expansionId) . cardExpansionId . entityVal) (catalogCards snapshot)
            pure (object ["expansion" .= expansionJson snapshot (Entity expansionId found)
                         , "cards" .= map (ownedCardJson snapshot) cards])

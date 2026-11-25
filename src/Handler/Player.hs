{-# LANGUAGE OverloadedStrings #-}
module Handler.Player (authenticatedPlayer) where

import Database.Persist (Entity(..), getBy)
import Foundation
import Model
import Yesod.Core (lookupSession, notAuthenticated)
import Yesod.Persist (YesodPersist(..))

-- Resolving an authenticated account must not mutate inventory.
authenticatedPlayer :: Handler (Entity User)
authenticatedPlayer = do
    sessionName <- lookupSession "username"
    case sessionName of
        Nothing -> notAuthenticated
        Just username -> do
            found <- runDB (getBy (UniqueUsername username))
            case found of
                Nothing -> notAuthenticated
                Just player -> pure player

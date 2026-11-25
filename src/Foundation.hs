{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE ViewPatterns #-}
module Foundation where

import Database.Persist.Postgresql (ConnectionPool, SqlBackend, runSqlPool)
import Database.Persist (getBy)
import Data.ByteString (ByteString)
import Model (Unique(..), ExpansionId)
import Network.HTTP.Types.Status (status400, status401, status403, status404, status405, status500)
import Data.Time.LocalTime.TimeZone.Series (TimeZoneSeries)
import Yesod.Core
import Yesod.Persist (YesodPersist(..))

data App = App
    { appPool :: ConnectionPool
    , appSessionBackend :: SessionBackend
    , appTimeZone :: TimeZoneSeries
    , appAllowedOrigin :: Maybe ByteString
    }

mkYesodData "App" [parseRoutes|
/ HomeR GET
/auth/csrf CsrfR GET
/register RegisterR POST
/login LoginR POST
/logout LogoutR POST
/dashboard DashboardR GET
/rewards/daily/claim ClaimDailyRewardR POST
/boosters BoosterR GET
/boosters/open OpenBoosterR POST
/boosters/last LastOpeningR GET
/collection CollectionR GET
/expansions ExpansionsR GET
/expansions/#ExpansionId ExpansionDetailR GET
|]

instance Yesod App where
    makeSessionBackend = pure . Just . appSessionBackend
    yesodMiddleware = defaultCsrfMiddleware . defaultYesodMiddleware
    errorHandler NotAuthenticated = sendResponseStatus status401 (object ["error" .= ("Authentication required" :: String)])
    errorHandler (PermissionDenied _) = sendResponseStatus status403 (object ["error" .= ("Forbidden" :: String)])
    errorHandler (InvalidArgs _) = sendResponseStatus status400 (object ["error" .= ("Invalid request" :: String)])
    errorHandler NotFound = sendResponseStatus status404 (object ["error" .= ("Not found" :: String)])
    errorHandler (BadMethod _) = sendResponseStatus status405 (object ["error" .= ("Method not allowed" :: String)])
    errorHandler (InternalError _) = sendResponseStatus status500 (object ["error" .= ("Internal server error" :: String)])
    isAuthorized route _ | privateRoute route = do
        username <- lookupSession "username"
        case username of
            Nothing -> pure AuthenticationRequired
            Just name -> do
                existing <- runDB (getBy (UniqueUsername name))
                pure $ maybe AuthenticationRequired (const Authorized) existing
    isAuthorized _ _ = pure Authorized

privateRoute :: Route App -> Bool
privateRoute DashboardR = True
privateRoute ClaimDailyRewardR = True
privateRoute BoosterR = True
privateRoute OpenBoosterR = True
privateRoute LastOpeningR = True
privateRoute CollectionR = True
privateRoute ExpansionsR = True
privateRoute (ExpansionDetailR _) = True
privateRoute _ = False

instance YesodPersist App where
    type YesodPersistBackend App = SqlBackend
    runDB action = do
        pool <- appPool <$> getYesod
        runSqlPool action pool

{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ViewPatterns #-}
module Application (runApplication) where

import Foundation
import Handler.Home
import Handler.Auth
import Handler.Dashboard
import Handler.Reward
import Handler.Booster
import Handler.Collection
import Network.Wai.Handler.Warp (run)
import Network.Wai.Middleware.Cors (cors, simpleCorsResourcePolicy, CorsResourcePolicy(..))
import Yesod.Core (mkYesodDispatch, toWaiApp)

mkYesodDispatch "App" resourcesApp

runApplication :: Int -> App -> IO ()
runApplication port app = do
    wai <- toWaiApp app
    let allowed = fmap (\origin -> simpleCorsResourcePolicy
            { corsOrigins = Just ([origin], True)
            , corsMethods = ["GET", "POST", "OPTIONS"]
            , corsRequestHeaders = ["content-type", "x-xsrf-token"]
            , corsVaryOrigin = True
            }) (appAllowedOrigin app)
    run port (cors (const allowed) wai)

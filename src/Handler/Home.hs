{-# LANGUAGE OverloadedStrings #-}
module Handler.Home (getHomeR) where

import Foundation (Handler)
import Yesod.Core (TypedContent, selectRep, provideRep, returnJson)

getHomeR :: Handler TypedContent
getHomeR = selectRep $ provideRep $ returnJson ("monadex backend online" :: String)

{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
module Handler.Auth (getCsrfR, postRegisterR, postLoginR, postLogoutR) where

import Data.Aeson (withObject)
import Data.Text (Text)
import qualified Data.Text as T
import Database.Persist (get)
import Foundation
import GHC.Generics (Generic)
import Model (User(..))
import Network.HTTP.Types.Status (status201, status400, status401, status500)
import Service.AuthService (authenticateUser, registerUser)
import Yesod.Core
import Yesod.Persist (YesodPersist(..))

data RegistrationRequest = RegistrationRequest
    { username :: Text, password :: Text, confirmation :: Text
    } deriving Generic
instance FromJSON RegistrationRequest

data LoginRequest = LoginRequest { loginUsername :: Text, loginPassword :: Text }
    deriving Generic
instance FromJSON LoginRequest where
    parseJSON = withObject "LoginRequest" $ \o ->
        LoginRequest <$> o .: "username" <*> o .: "password"

getCsrfR :: Handler Value
getCsrfR = do
    token <- reqToken <$> getRequest
    pure (object ["csrfToken" .= token])

postRegisterR :: Handler Value
postRegisterR = do
    input <- requireCheckJsonBody
    result <- runDB $ registerUser (username input) (password input) (confirmation input)
    case result of
        Left failure -> sendResponseStatus status400 (object ["error" .= show failure])
        Right userId -> do
            user <- runDB (get userId)
            case user of
                Nothing -> sendResponseStatus status500 (object ["error" .= ("Registration failed" :: Text)])
                Just registered -> do
                    setSession "username" (userUsername registered)
                    sendResponseStatus status201 (object ["username" .= userUsername registered])

postLoginR :: Handler Value
postLoginR = do
    input <- requireCheckJsonBody
    if T.length (loginUsername input) > 32 || T.length (loginPassword input) > 1024
        then sendResponseStatus status401 (object ["error" .= ("Invalid credentials" :: Text)])
        else do
            found <- runDB $ authenticateUser (loginUsername input) (loginPassword input)
            case found of
                Nothing -> sendResponseStatus status401 (object ["error" .= ("Invalid credentials" :: Text)])
                Just _ -> do
                    setSession "username" (T.toLower (loginUsername input))
                    pure (object ["username" .= T.toLower (loginUsername input)])

postLogoutR :: Handler Value
postLogoutR = do
    deleteSession "username"
    pure (object ["loggedOut" .= True])

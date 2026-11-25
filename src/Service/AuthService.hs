{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Service.AuthService
    ( RegistrationError(..), validateRegistration, hashPassword, verifyPassword
    , registerUser, authenticateUser ) where

import Crypto.KDF.PBKDF2 (Parameters(..), fastPBKDF2_SHA256)
import Crypto.Random (getRandomBytes)
import Data.ByteArray (constEq)
import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Base64 as Base64
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (decodeUtf8, encodeUtf8)
import Data.Time (UTCTime, getCurrentTime, diffUTCTime, addUTCTime)
import Database.Persist (Entity(..), getBy, insert, insertUnique, deleteBy, toPersistValue)
import Database.Persist.Sql (SqlPersistT, Single(..), rawSql)
import Control.Exception (evaluate)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Model

data RegistrationError = InvalidUsername | InvalidPassword | PasswordMismatch | UsernameTaken
    deriving (Show, Eq)

-- Canonical lowercase names avoid case-insensitive duplicates.
validateRegistration :: Text -> Text -> Text -> Either RegistrationError Text
validateRegistration username password confirmation
    | T.length name < 3 || T.length name > 32
      || T.any (\c -> not (c >= 'a' && c <= 'z' || c >= '0' && c <= '9' || c == '_')) name =
        Left InvalidUsername
    | T.length password < 12 || T.length password > 1024 = Left InvalidPassword
    | password /= confirmation = Left PasswordMismatch
    | otherwise = Right name
  where name = T.toLower username

parameters :: Parameters
parameters = Parameters { iterCounts = 210000, outputLength = 32 }

hashPassword :: Text -> IO Text
hashPassword password = do
    salt <- getRandomBytes 16
    let digest = fastPBKDF2_SHA256 parameters (encodeUtf8 password) salt
    pure (T.intercalate "$" ["pbkdf2-sha256", "210000", encode64 salt, encode64 digest])

verifyPassword :: Text -> Text -> Bool
verifyPassword password encoded = case T.splitOn "$" encoded of
    ["pbkdf2-sha256", "210000", saltText, digestText] ->
        case (Base64.decode (encodeUtf8 saltText), Base64.decode (encodeUtf8 digestText)) of
            (Right salt, Right digest)
                | BS.length salt == 16 && BS.length digest == 32 ->
                    constEq (fastPBKDF2_SHA256 parameters (encodeUtf8 password) salt :: ByteString) digest
            _ -> False
    _ -> False

encode64 :: ByteString -> Text
encode64 = decodeUtf8 . Base64.encode

registerUser :: MonadIO m => Text -> Text -> Text -> SqlPersistT m (Either RegistrationError UserId)
registerUser username password confirmation = case validateRegistration username password confirmation of
    Left failure -> pure (Left failure)
    Right name -> do
        hashed <- liftIO (hashPassword password)
        now <- liftIO getCurrentTime
        inserted <- insertUnique (User name hashed now)
        case inserted of
            Nothing -> pure (Left UsernameTaken)
            Just userId -> do
                _ <- insert (BoosterInventory userId 0)
                pure (Right userId)

-- A fixed, non-matching PBKDF2 hash. Verifying it spends the same work as a
-- real account check, so response timing does not reveal which usernames exist.
placeholderHash :: Text
placeholderHash = "pbkdf2-sha256$210000$nyx6HU6LPFptDx4qO0xdbg==$xZFnvkQ3N8leEASOTXYYn1z+SRB1e7W60JrYwKEvX5U="

authenticateUser :: MonadIO m => Text -> Text -> SqlPersistT m (Maybe UserId)
authenticateUser username password = do
    now <- liftIO getCurrentTime
    let name = T.toLower username
    attempt <- getBy (UniqueAuthAttemptUsername name)
    if maybe False (\(Entity _ entry) -> authAttemptFailedCount entry >= 5
                     && diffUTCTime now (authAttemptLastFailedAt entry) < 900) attempt
        then pure Nothing
        else do
            found <- getBy (UniqueUsername name)
            case found of
                Nothing -> do
                    _ <- liftIO (evaluate (verifyPassword password placeholderHash))
                    recordFailure name now
                    pure Nothing
                Just (Entity userId user)
                    | verifyPassword password (userPasswordHash user) -> do
                        deleteBy (UniqueAuthAttemptUsername name)
                        pure (Just userId)
                    | otherwise -> do
                        recordFailure name now
                        pure Nothing

-- PostgreSQL serializes conflicting upserts on the unique username.
recordFailure :: MonadIO m => Text -> UTCTime -> SqlPersistT m ()
recordFailure name now = do
    _counts :: [Single Int] <- rawSql
        "INSERT INTO auth_attempt (username, failed_count, last_failed_at) VALUES (?, 1, ?) ON CONFLICT (username) DO UPDATE SET failed_count = CASE WHEN auth_attempt.last_failed_at < ? THEN 1 ELSE auth_attempt.failed_count + 1 END, last_failed_at = EXCLUDED.last_failed_at RETURNING failed_count"
        [toPersistValue name, toPersistValue now,
         toPersistValue (addUTCTime (-900) now)]
    pure ()

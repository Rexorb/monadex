{-# LANGUAGE OverloadedStrings #-}
module HttpSpec (httpSpec) where

import Application ()
import Control.Monad.IO.Class (liftIO)
import Control.Monad.Logger (runNoLoggingT)
import Crypto.Random (getRandomBytes)
import Data.Aeson (Value(..), encode, object, (.=))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import Data.ByteString.Char8 (pack)
import Data.Foldable (foldl')
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time.LocalTime.TimeZone.Olson (getTimeZoneSeriesFromOlsonFile)
import Database.Persist (Entity(..), getBy)
import Database.Persist.Postgresql (createPostgresqlPool, runSqlPool)
import Database.Persist.Sql (Single(..), rawSql)
import Foundation
import Model
import Network.Wai.Test (SResponse(..))
import Numeric (showHex)
import System.Environment (lookupEnv)
import Test.Hspec
import Yesod.Core (defaultClientSessionBackend, strictSameSiteSessions)
import Yesod.Test

httpSpec :: Spec
httpSpec = do
    connection <- runIO (lookupEnv "MONADEX_TEST_DATABASE_URL")
    case connection of
        Nothing -> describe "Yesod HTTP (isolated test database)" $
            it "requires MONADEX_TEST_DATABASE_URL" $
                pendingWith "HTTP integration tests require the isolated database"
        Just url -> yesodSpecWithSiteGenerator (testSite url) $ do
            ydescribe "authenticated JSON and daily reward" $ do
                yit "requires authentication and CSRF, and GET never grants a reward" $ do
                    get DashboardR
                    statusIs 401
                    response <- requireJSONResponse
                    assertEq "JSON authentication error" (field "error" response) (Just (String "Authentication required"))
                    get CsrfR
                    statusIs 200
                    claim
                    statusIs 401
                    username <- randomUsername
                    register username False
                    statusIs 403
                    register username True
                    statusIs 201
                    withResponse $ \response -> liftIO $ do
                        let cookies = [value | (name, value) <- simpleHeaders response
                                      , name == "Set-Cookie", "_SESSION=" `BS.isPrefixOf` value]
                        cookies `shouldSatisfy` (not . null)
                        all (BS.isInfixOf "HttpOnly") cookies `shouldBe` True
                        all (BS.isInfixOf "SameSite=Strict") cookies `shouldBe` True
                    registration <- requireJSONResponse
                    assertEq "username" (field "username" registration) (Just (String username))
                    register username True
                    statusIs 400
                    register (T.toUpper username) True
                    statusIs 400
                    get DashboardR
                    statusIs 200
                    dashboard <- requireJSONResponse
                    assertEq "GET booster balance" (field "boosters" dashboard) (Just (Number 0))
                    assertEq "GET unclaimed status" (field "claimed" =<< field "dailyReward" dashboard) (Just (Bool False))
                    get BoosterR
                    statusIs 200
                    get CollectionR
                    statusIs 200
                    collectionView <- requireJSONResponse
                    assertEq "collection unique owned" (field "uniqueOwned" collectionView) (Just (Number 0))
                    assertEq "catalog entries" (maybe False (>= 4) (arrayLength (field "cards" collectionView))) True
                    get ExpansionsR
                    statusIs 200
                    expansions <- requireJSONResponse
                    assertEq "expansion list" (maybe False (>= 1) (arrayLength (field "expansions" expansions))) True
                    get LastOpeningR
                    statusIs 200
                    app <- getTestYesod
                    user <- liftIO $ runNoLoggingT $ runSqlPool (getBy (UniqueUsername username)) (appPool app)
                    case user of
                        Nothing -> liftIO (expectationFailure "missing registered account")
                        Just (Entity userId _) -> do
                            inventory <- liftIO $ runNoLoggingT $ runSqlPool (getBy (UniqueInventoryUser userId)) (appPool app)
                            reward <- liftIO $ runNoLoggingT $ runSqlPool (getBy (UniqueRewardUser userId)) (appPool app)
                            assertEq "GET does not change inventory" (fmap (boosterInventoryQuantity . entityVal) inventory) (Just 0)
                            assertEq "GET does not insert a reward" (fmap entityKey reward) Nothing
                    request $ do
                        setMethod "POST"
                        setUrl ClaimDailyRewardR
                    statusIs 403
                    claim
                    statusIs 200
                    first <- requireJSONResponse
                    assertEq "first claim grants" (field "grantedNow" first) (Just (Bool True))
                    assertEq "first claim balance" (field "boosters" first) (Just (Number 1))
                    claim
                    statusIs 200
                    again <- requireJSONResponse
                    assertEq "repeat is idempotent" (field "grantedNow" again) (Just (Bool False))
                    assertEq "repeat balance" (field "boosters" again) (Just (Number 1))
                    get DashboardR
                    statusIs 200
                    after <- requireJSONResponse
                    assertEq "claimed after POST" (field "claimed" =<< field "dailyReward" after) (Just (Bool True))

                yit "opens a six-card pack once and isolates collections across sessions" $ do
                    get CsrfR
                    firstName <- randomUsername
                    register firstName True
                    statusIs 201
                    claim
                    statusIs 200
                    request $ do
                        setMethod "POST"
                        setUrl OpenBoosterR
                        addTokenFromCookie
                    statusIs 200
                    opened <- requireJSONResponse
                    let cards = field "cards" opened
                    assertEq "six cards" (arrayLength cards) (Just 6)
                    assertEq "sixth allowed" ((field "rarity" =<< arrayLast cards)
                        `elem` map (Just . String) ["Uncommon", "Rare", "UltraRare"]) True
                    assertEq "image field present" (maybe False (const True) (field "imageUrl" =<< arrayLast cards)) True
                    get LastOpeningR
                    statusIs 200
                    latest <- requireJSONResponse
                    assertEq "same stored result" (field "cards" latest) cards
                    get BoosterR
                    statusIs 200
                    available <- requireJSONResponse
                    assertEq "GET does not consume" (field "available" available) (Just (Number 0))
                    request $ do
                        setMethod "POST"
                        setUrl OpenBoosterR
                        addTokenFromCookie
                    statusIs 409
                    insufficient <- requireJSONResponse
                    assertEq "no inventory" (field "error" insufficient) (Just (String "InsufficientBoosters"))
                    testClearCookies
                    get CsrfR
                    secondName <- randomUsername
                    register secondName True
                    statusIs 201
                    get DashboardR
                    statusIs 200
                    other <- requireJSONResponse
                    assertEq "other user copies" (field "totalCards" other) (Just (Number 0))
                    get LastOpeningR
                    statusIs 200
                    otherOpening <- requireJSONResponse
                    assertEq "other user history" (arrayLength (field "cards" otherOpening)) (Just 0)

                yit "rejects malformed JSON, invalid login and logs out" $ do
                    get CsrfR
                    username <- randomUsername
                    request $ do
                        setMethod "POST"
                        setUrl RegisterR
                        addTokenFromCookie
                        addRequestHeader ("Content-Type", "application/json")
                        setRequestBody "{"
                    statusIs 400
                    malformed <- requireJSONResponse
                    assertEq "invalid JSON response" (field "error" malformed) (Just (String "Invalid request"))
                    request $ do
                        setMethod "POST"
                        setUrl RegisterR
                        addTokenFromCookie
                        addRequestHeader ("Content-Type", "application/json")
                        setRequestBody $ encode (object ["username" .= username, "password" .= ("integration-password-123" :: Text)])
                    statusIs 400
                    register username True
                    statusIs 201
                    request $ do
                        setMethod "POST"
                        setUrl LoginR
                        addTokenFromCookie
                        addRequestHeader ("Content-Type", "application/json")
                        setRequestBody $ encode (object ["username" .= username, "password" .= ("wrong-password" :: Text)])
                    statusIs 401
                    invalid <- requireJSONResponse
                    assertEq "generic login error" (field "error" invalid) (Just (String "Invalid credentials"))
                    request $ do
                        setMethod "POST"
                        setUrl LogoutR
                        addTokenFromCookie
                    statusIs 200
                    get DashboardR
                    statusIs 401
                    request $ do
                        setMethod "POST"
                        setUrl LoginR
                        addTokenFromCookie
                        addRequestHeader ("Content-Type", "application/json")
                        setRequestBody $ encode (object ["username" .= username, "password" .= ("integration-password-123" :: Text)])
                    statusIs 200
                    get DashboardR
                    statusIs 200

testSite :: String -> IO App
testSite url = do
    if not ("dbname=monadex_test_db" `T.isInfixOf` T.pack url)
        then ioError (userError "HTTP tests require monadex_test_db")
        else pure ()
    pool <- runNoLoggingT (createPostgresqlPool (pack url) 6)
    actual <- runNoLoggingT $ runSqlPool (rawSql "SELECT current_database()" []) pool
    if actual /= [Single ("monadex_test_db" :: Text)]
        then ioError (userError "HTTP tests refused unexpected database")
        else runNoLoggingT (runSqlPool migrateMonadex pool)
    zone <- getTimeZoneSeriesFromOlsonFile "/usr/share/zoneinfo/America/Sao_Paulo"
    backend <- defaultClientSessionBackend 120 "/tmp/opencode/monadex-http-test-session.key"
    secured <- strictSameSiteSessions (pure (Just backend))
    pure (App pool (maybe backend id secured) zone Nothing)

randomUsername :: YesodExample App Text
randomUsername = do
    salt <- liftIO (getRandomBytes 8 :: IO ByteString)
    pure ("http_" <> T.pack (concatMap (`showHex` "") (BS.unpack salt)))

register :: Text -> Bool -> YesodExample App ()
register name withToken = request $ do
    setMethod "POST"
    setUrl RegisterR
    if withToken then addTokenFromCookie else pure ()
    addRequestHeader ("Content-Type", "application/json")
    setRequestBody $ encode (object
        ["username" .= name, "password" .= ("integration-password-123" :: Text)
        , "confirmation" .= ("integration-password-123" :: Text)])

claim :: YesodExample App ()
claim = request $ do
    setMethod "POST"
    setUrl ClaimDailyRewardR
    addTokenFromCookie

field :: Text -> Value -> Maybe Value
field name (Object obj) = KeyMap.lookup (Key.fromText name) obj
field _ _ = Nothing

arrayLength :: Maybe Value -> Maybe Int
arrayLength (Just (Array items)) = Just (length items)
arrayLength _ = Nothing

arrayLast :: Maybe Value -> Maybe Value
arrayLast (Just (Array items)) = foldl' (\_ item -> Just item) Nothing items
arrayLast _ = Nothing

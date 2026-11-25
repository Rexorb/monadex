{-# LANGUAGE OverloadedStrings #-}
module Integration (integrationSpec) where

import Control.Concurrent.Async (concurrently)
import Control.Exception (SomeException, try)
import Control.Monad.IO.Class (liftIO)
import Control.Monad.Logger (runNoLoggingT)
import Crypto.Random (getRandomBytes)
import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import Data.ByteString.Char8 (pack)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T
import Data.List (sort)
import Data.Time (UTCTime(..), addDays, secondsToDiffTime)
import Data.Time.LocalTime.TimeZone.Olson (getTimeZoneSeriesFromOlsonFile)
import Database.Persist (Entity(..), count, getBy, selectList, toPersistValue, upsertBy, (==.))
import Database.Persist.Postgresql (ConnectionPool, runSqlPool, withPostgresqlPool)
import Database.Persist.Sql (Single(..), rawExecute, rawSql)
import Domain.Error (GameError(..))
import Domain.Rarity (Rarity(..))
import Model
import Numeric (showHex)
import Service.AuthService (RegistrationError(..), registerUser, verifyPassword)
import Service.BoosterService (openPersistedBooster)
import Service.CollectionService (loadCollection, ownedQuantities)
import Service.DailyRewardService (grantDailyReward, grantDailyRewardAt)
import System.Environment (lookupEnv)
import Test.Hspec

integrationSpec :: Spec
integrationSpec = do
    connection <- runIO (lookupEnv "MONADEX_TEST_DATABASE_URL")
    describe "PostgreSQL integration (isolated test database)" $
        case connection of
            Nothing -> it "requires MONADEX_TEST_DATABASE_URL" $
                pendingWith "Set an isolated database URL to run SQL/concurrency tests"
            Just url
                | not ("dbname=monadex_test_db" `T.isInfixOf` T.pack url) ->
                    it "refuses the application database" $
                        expectationFailure "Use dbname=monadex_test_db for integration tests"
                | otherwise -> it "atomically registers, rewards and opens under concurrent requests" $ do
                    zone <- getTimeZoneSeriesFromOlsonFile "/usr/share/zoneinfo/America/Sao_Paulo"
                    salt <- getRandomBytes 8 :: IO ByteString
                    let username = "integration_" <> T.pack (concatMap (`showHex` "") (BS.unpack salt))
                    runNoLoggingT $ withPostgresqlPool (pack url) 8 $ \pool -> do
                        actualDatabase <- runSqlPool (rawSql "SELECT current_database()" []) pool
                        liftIO $ actualDatabase `shouldBe` [Single ("monadex_test_db" :: Text)]
                        runSqlPool migrateMonadex pool
                        runSqlPool migrateMonadex pool
                        constraints <- runSqlPool (rawSql
                            "SELECT conname FROM pg_constraint WHERE conname IN ('collection_quantity_positive','inventory_quantity_nonnegative','card_rarity_valid','opening_card_position_valid') ORDER BY conname" []) pool
                        liftIO $ (constraints :: [Single Text]) `shouldBe`
                            map Single ["card_rarity_valid", "collection_quantity_positive",
                                        "inventory_quantity_nonnegative", "opening_card_position_valid"]
                        (uid, passwordHash) <- runSqlPool (do
                            created <- registerUser username "integration-password-123" "integration-password-123"
                            case created of
                                Left failure -> liftIO (expectationFailure (show failure)) >> fail "registration failed"
                                Right uid -> do
                                    found <- getBy (UniqueUsername username)
                                    pure (uid, maybe "" (userPasswordHash . entityVal) found)) pool
                        liftIO $ do
                            passwordHash `shouldNotBe` "integration-password-123"
                            verifyPassword "integration-password-123" passwordHash `shouldBe` True
                        duplicate <- runSqlPool (registerUser username "integration-password-123" "integration-password-123") pool
                        liftIO $ duplicate `shouldBe` Left UsernameTaken
                        secondAccount <- runSqlPool
                            (registerUser (T.take 27 username <> "_b") "integration-password-123" "integration-password-123") pool
                        secondId <- case secondAccount of
                            Left failure -> liftIO (expectationFailure (show failure)) >> fail "registration failed"
                            Right otherId -> pure otherId
                        initialInventory <- runSqlPool (getBy (UniqueInventoryUser uid)) pool
                        liftIO $ fmap (boosterInventoryQuantity . entityVal) initialInventory `shouldBe` Just 0
                        invalidInventory <- liftIO (try (runNoLoggingT $ runSqlPool
                            (rawExecute "UPDATE booster_inventory SET quantity = -1 WHERE user_id = ?"
                                [toPersistValue uid]) pool) :: IO (Either SomeException ()))
                        liftIO $ case invalidInventory of
                            Left _ -> pure ()
                            Right () -> expectationFailure "negative inventory was accepted"
                        unchanged <- runSqlPool (getBy (UniqueInventoryUser uid)) pool
                        liftIO $ fmap (boosterInventoryQuantity . entityVal) unchanged `shouldBe` Just 0
                        liftIO $ prepareFixture pool
                        liftIO $ prepareFixture pool
                        fixtureCount <- runSqlPool (count [CardExternalId ==. "test-only-c"]) pool
                        liftIO $ fixtureCount `shouldBe` 1
                        (rewardA, rewardB) <- liftIO $ concurrently
                            (runNoLoggingT (runSqlPool (grantDailyReward zone uid) pool))
                            (runNoLoggingT (runSqlPool (grantDailyReward zone uid) pool))
                        let grants = [granted | Right (_, granted) <- [rewardA, rewardB]]
                        liftIO $ sort grants `shouldBe` [False, True]
                        independent <- runSqlPool (grantDailyReward zone secondId) pool
                        liftIO $ (snd <$> independent) `shouldBe` Right True
                        inventory <- runSqlPool (getBy (UniqueInventoryUser uid)) pool
                        liftIO $ fmap (boosterInventoryQuantity . entityVal) inventory `shouldBe` Just 1
                        (openedA, openedB) <- liftIO $ concurrently
                            (runNoLoggingT (runSqlPool (openPersistedBooster uid) pool))
                            (runNoLoggingT (runSqlPool (openPersistedBooster uid) pool))
                        let successes = [cards | Right cards <- [openedA, openedB]]
                        liftIO $ do
                            length successes `shouldBe` 1
                            map length successes `shouldBe` [6]
                            length [() | Left InsufficientBoosters <- [openedA, openedB]] `shouldBe` 1
                        finalInventory <- runSqlPool (getBy (UniqueInventoryUser uid)) pool
                        owned <- runSqlPool (selectList [CollectionUserId ==. uid] []) pool
                        otherCollection <- runSqlPool (loadCollection secondId) pool
                        otherInventory <- runSqlPool (getBy (UniqueInventoryUser secondId)) pool
                        openings <- runSqlPool (count [BoosterOpeningUserId ==. uid]) pool
                        liftIO $ do
                            fmap (boosterInventoryQuantity . entityVal) finalInventory `shouldBe` Just 0
                            sum (map (collectionQuantity . entityVal) owned) `shouldBe` 6
                            openings `shouldBe` 1
                            Map.null (ownedQuantities otherCollection) `shouldBe` True
                            fmap (boosterInventoryQuantity . entityVal) otherInventory `shouldBe` Just 1
                        case rewardA of
                            Left failure -> liftIO (expectationFailure (show failure))
                            Right (today, _) -> do
                                let nextDay = UTCTime (addDays 1 today) (secondsToDiffTime (12 * 3600))
                                tomorrow <- runSqlPool (grantDailyRewardAt zone nextDay uid) pool
                                repeated <- runSqlPool (grantDailyRewardAt zone nextDay uid) pool
                                liftIO $ do
                                    (snd <$> tomorrow) `shouldBe` Right True
                                    (snd <$> repeated) `shouldBe` Right False
                                nextInventory <- runSqlPool (getBy (UniqueInventoryUser uid)) pool
                                liftIO $ fmap (boosterInventoryQuantity . entityVal) nextInventory `shouldBe` Just 1

prepareFixture :: ConnectionPool -> IO ()
prepareFixture pool = runNoLoggingT $ runSqlPool (do
    Entity expansionId _ <- upsertBy (UniqueExpansionExternal "test-only-expansion")
        (Expansion "test-only-expansion" "TEST FIXTURE" Nothing Nothing) []
    mapM_ (\(suffix, rarity) -> do
        _ <- upsertBy (UniqueCardExternal ("test-only-" <> suffix))
            (Card ("test-only-" <> suffix) expansionId "Test card" Nothing
                (Just (T.pack (show rarity))) rarity suffix Nothing) []
        pure ()) [("c", Common), ("u", Uncommon), ("r", Rare), ("x", UltraRare)]
    ) pool

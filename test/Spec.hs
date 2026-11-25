{-# LANGUAGE OverloadedStrings #-}
module Main (main) where

import Control.Monad.State.Strict (runStateT)
import qualified Data.ByteString.Lazy.Char8 as BL
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import Data.Time (UTCTime(..), fromGregorian, secondsToDiffTime)
import Data.Time.LocalTime.TimeZone.Olson (getTimeZoneSeriesFromOlsonFile)
import Domain.Booster (BoosterConfig(..), drawBooster, openBooster, standardConfig)
import Domain.Card (Card(..), CardId(..), CardPool)
import Domain.Error (GameError(..))
import Domain.Player (PlayerState(..), claimDailyReward)
import Domain.Rarity (Rarity(..), Weights(..), drawRarity)
import System.Random (mkStdGen)
import Service.CardAPI (ApiCard(..), ApiSet(..), CardSummary(..), ImportError(..),
    decodeCard, decodeSet, fetchWith, normalizeRarity)
import Network.HTTP.Client (HttpException(..), HttpExceptionContent(..), parseRequest)
import Service.CardImportService (ImportReport(..), prepareCatalog)
import Service.AuthService (RegistrationError(..), hashPassword, validateRegistration, verifyPassword)
import Service.CollectionService (progressPercent)
import Service.DailyRewardService (localDay)
import Test.Hspec
import Integration (integrationSpec)
import HttpSpec (httpSpec)

main :: IO ()
main = hspec $ do
    describe "booster draw" $ do
        it "draws six cards with a non-Common sixth for controlled seeds" $
            mapM_ (\seed -> case drawBooster standardConfig catalog (mkStdGen seed) of
                Left failure -> expectationFailure (show failure)
                Right (cards, _) -> do
                    length cards `shouldBe` 6
                    fmap cardRarity (Map.lookup (last cards) catalog)
                        `shouldSatisfy` (`elem` map Just [Uncommon, Rare, UltraRare])
                ) [0..100]
        it "does not silently rebalance an incomplete catalog" $
            drawBooster standardConfig (Map.delete (CardId "ultra") catalog) (mkStdGen 1)
                `shouldBe` Left (EmptyCardPool UltraRare)
        it "rejects invalid weights and Common in the final slot" $
            drawBooster (BoosterConfig (Weights []) (Weights [(Common, 1)])) catalog (mkStdGen 1)
                `shouldBe` Left InvalidWeights
        it "selects rarity according to configured integer intervals" $ do
            drawRarity (Weights [(Common, 60), (Uncommon, 25), (Rare, 10), (UltraRare, 5)]) 60 `shouldBe` Just Common
            drawRarity (Weights [(Common, 60), (Uncommon, 25), (Rare, 10), (UltraRare, 5)]) 61 `shouldBe` Just Uncommon
    describe "booster transition" $ do
        let cards = replicate 5 (CardId "common") ++ [CardId "rare"]
        it "consumes exactly one and aggregates repeated copies" $ do
            let Right (result, player) = runStateT (openBooster catalog cards) emptyPlayer { boosterCount = 2 }
            length result `shouldBe` 6
            boosterCount player `shouldBe` 1
            Map.lookup (CardId "common") (collection player) `shouldBe` Just 5
            Map.lookup (CardId "rare") (collection player) `shouldBe` Just 1
            Map.size (collection player) `shouldBe` 2
        it "rejects empty inventory without changing it" $
            runStateT (openBooster catalog cards) emptyPlayer `shouldBe` Left InsufficientBoosters
        it "rejects missing cards without consuming inventory" $
            runStateT (openBooster catalog (replicate 5 (CardId "missing") ++ [CardId "rare"])) emptyPlayer { boosterCount = 1 }
                `shouldBe` Left CardNotFound
        it "rejects a Common sixth and malformed packs" $ do
            runStateT (openBooster catalog (replicate 6 (CardId "common"))) emptyPlayer { boosterCount = 1 }
                `shouldBe` Left InvalidBooster
            runStateT (openBooster catalog []) emptyPlayer { boosterCount = 1 }
                `shouldBe` Left InvalidBooster
        it "rejects negative inventory" $
            runStateT (openBooster catalog cards) emptyPlayer { boosterCount = -1 }
                `shouldBe` Left InvalidPlayerState
    describe "daily reward transition" $ do
        let today = fromGregorian 2026 11 24
            tomorrow = fromGregorian 2026 11 25
        it "grants one on the first eligible day and none again on that day" $
            case runStateT (claimDailyReward today) emptyPlayer of
                Left failure -> expectationFailure (show failure)
                Right ((), player) -> do
                    boosterCount player `shouldBe` 1
                    lastClaim player `shouldBe` Just today
                    runStateT (claimDailyReward today) player `shouldBe` Left DailyRewardAlreadyClaimed
        it "grants again on a new day and isolates independent states" $ do
            let Right ((), player) = runStateT (claimDailyReward today) emptyPlayer
                Right ((), nextDay) = runStateT (claimDailyReward tomorrow) player
            boosterCount nextDay `shouldBe` 2
            runStateT (claimDailyReward today) emptyPlayer `shouldBe` Right ((), player)
        it "does not grant for a date earlier than the last claim" $
            runStateT (claimDailyReward today) emptyPlayer { lastClaim = Just tomorrow }
                `shouldBe` Left DailyRewardAlreadyClaimed
    describe "TCGdex parsing and catalog validation" $ do
        it "decodes real response shapes and accepts missing optional fields" $ do
            decodeSet (BL.pack "{\"id\":\"swsh12\",\"name\":\"Silver Tempest\",\"cards\":[{\"id\":\"swsh12-001\"}]}")
                `shouldBe` Right (ApiSet "swsh12" "Silver Tempest" Nothing Nothing [CardSummary "swsh12-001"])
            decodeCard (BL.pack "{\"id\":\"swsh12-001\",\"name\":\"Venonat\",\"localId\":\"001\"}")
                `shouldBe` Right (ApiCard "swsh12-001" "Venonat" "001" Nothing Nothing Nothing)
        it "rejects invalid JSON or missing required card fields" $ do
            decodeCard (BL.pack "not-json") `shouldSatisfy` isInvalidResponse
            decodeCard (BL.pack "{\"id\":\"x\"}") `shouldSatisfy` isInvalidResponse
        it "maps explicit rarities without defaulting unknowns to Common" $ do
            normalizeRarity "Holo Rare VSTAR" `shouldBe` Just UltraRare
            normalizeRarity "Uncommon" `shouldBe` Just Uncommon
            normalizeRarity "unknown" `shouldBe` Nothing
            normalizeRarity "Promo" `shouldBe` Nothing
        it "rejects incomplete catalogs before writes" $
            prepareCatalog sampleSet sampleCards `shouldBe` Left (IncompleteCatalog UltraRare)
        it "skips unknown labels and retains all four required rarities" $
            prepareCatalog sampleSet (replaceLast UltraRare sampleCards)
                `shouldBe` Right (take 4 (zip (replaceLast UltraRare sampleCards) [Common, Uncommon, Rare, UltraRare]),
                                  ImportReport 4 (Map.singleton "Unknown" 1))
        it "handles offline HTTP errors without parsing their response body" $ do
            result <- fetchWith (\_ -> pure (Right (503, BL.pack "not-json"))) "sets/swsh12" decodeSet
            result `shouldBe` Left (ApiFailure "HTTP 503")
        it "handles offline timeouts and malformed JSON" $ do
            request <- parseRequest "https://api.tcgdex.net/v2/en/sets/swsh12"
            let timeout _ = pure (Left (HttpExceptionRequest request ResponseTimeout))
            timedOut <- fetchWith timeout "sets/swsh12" decodeSet
            timedOut `shouldSatisfy` isApiFailure
            invalid <- fetchWith (\_ -> pure (Right (200, BL.pack "not-json"))) "sets/swsh12" decodeSet
            invalid `shouldSatisfy` isInvalidResponse
    describe "authentication primitives" $ do
        it "normalizes usernames and rejects invalid passwords and confirmation" $ do
            validateRegistration "Alice_42" "strong-password-123" "strong-password-123" `shouldBe` Right "alice_42"
            validateRegistration "a b" "strong-password-123" "strong-password-123" `shouldBe` Left InvalidUsername
            validateRegistration "alice" "short" "short" `shouldBe` Left InvalidPassword
            validateRegistration "alice" "strong-password-123" "different-password" `shouldBe` Left PasswordMismatch
        it "uses random salts and checks passwords without storing plaintext" $ do
            first <- hashPassword "strong-password-123"
            second <- hashPassword "strong-password-123"
            first `shouldNotBe` second
            first `shouldNotBe` "strong-password-123"
            verifyPassword "strong-password-123" first `shouldBe` True
            verifyPassword "wrong-password" first `shouldBe` False
            verifyPassword "strong-password-123" "invalid-hash" `shouldBe` False
    describe "collection progress and daily timezone" $ do
        it "handles empty expansions and clamps invalid counts" $ do
            progressPercent 0 0 `shouldBe` 0
            progressPercent 3 10 `shouldBe` 30
            progressPercent 12 10 `shouldBe` 100
            progressPercent (-1) 10 `shouldBe` 0
        it "uses the Sao Paulo date rather than the UTC date around midnight" $ do
            zone <- getTimeZoneSeriesFromOlsonFile "/usr/share/zoneinfo/America/Sao_Paulo"
            localDay zone (UTCTime (fromGregorian 2026 11 25) (secondsToDiffTime 3600))
                `shouldBe` fromGregorian 2026 11 24
            localDay zone (UTCTime (fromGregorian 2026 11 25) (secondsToDiffTime (4 * 3600)))
                `shouldBe` fromGregorian 2026 11 25
    integrationSpec
    httpSpec

catalog :: CardPool
catalog = Map.fromList [(cardId card, card) | card <-
    [ Card (CardId "common") Common, Card (CardId "uncommon") Uncommon
    , Card (CardId "rare") Rare, Card (CardId "ultra") UltraRare ]]

emptyPlayer :: PlayerState
emptyPlayer = PlayerState 0 Map.empty Nothing

isInvalidResponse :: Either ImportError a -> Bool
isInvalidResponse (Left (InvalidResponse _)) = True
isInvalidResponse _ = False

isApiFailure :: Either ImportError a -> Bool
isApiFailure (Left (ApiFailure _)) = True
isApiFailure _ = False

sampleSet :: ApiSet
sampleSet = ApiSet "swsh12" "Silver Tempest" Nothing Nothing
    [CardSummary (cardIdText n) | n <- [1..5]]

sampleCards :: [ApiCard]
sampleCards = zipWith (\n rarity -> ApiCard (cardIdText n) "Sample" "1" (Just rarity) Nothing Nothing)
    [1..5] ["Common", "Uncommon", "Rare", "Unknown", "Unknown"]

replaceLast :: Rarity -> [ApiCard] -> [ApiCard]
replaceLast _ cards = take 3 cards ++
    [ApiCard (cardIdText 4) "Sample" "4" (Just "Ultra Rare") Nothing Nothing,
     ApiCard (cardIdText 5) "Sample" "5" (Just "Unknown") Nothing Nothing]

cardIdText :: Int -> T.Text
cardIdText n = T.pack ("swsh12-" ++ show n)

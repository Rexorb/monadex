{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
module Service.CardAPI
    ( ApiSet(..), ApiCard(..), CardSummary(..), ImportError(..)
    , decodeSet, decodeCard, fetchSet, fetchCard, fetchWith, normalizeRarity ) where

import Control.Exception (try)
import Data.Aeson (FromJSON(..), eitherDecode, withObject, (.:), (.:?))
import qualified Data.ByteString.Lazy as BL
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, defaultTimeLocale, parseTimeM)
import Domain.Rarity (Rarity(..))
import GHC.Generics (Generic)
import Network.HTTP.Client (HttpException, responseTimeoutMicro)
import Network.HTTP.Simple (getResponseBody, getResponseStatusCode, httpLBS, parseRequest,
    setRequestResponseTimeout)

data CardSummary = CardSummary { summaryId :: Text }
    deriving (Show, Eq, Generic)

instance FromJSON CardSummary where
    parseJSON = withObject "CardSummary" $ \o -> CardSummary <$> o .: "id"

data ApiSet = ApiSet
    { setId :: Text, setName :: Text, setLogo :: Maybe Text
    , setReleaseDate :: Maybe Day, setCards :: [CardSummary]
    } deriving (Show, Eq)

instance FromJSON ApiSet where
    parseJSON = withObject "ApiSet" $ \o -> do
        release <- o .:? "releaseDate"
        ApiSet <$> o .: "id" <*> o .: "name" <*> o .:? "logo"
               <*> traverse (parseTimeM True defaultTimeLocale "%F" . T.unpack) release
               <*> o .: "cards"

data ApiCard = ApiCard
    { apiCardId :: Text, apiCardName :: Text, apiCardNumber :: Text
    , apiCardRarity :: Maybe Text, apiCardImage :: Maybe Text
    , apiCardCategory :: Maybe Text
    } deriving (Show, Eq)

instance FromJSON ApiCard where
    parseJSON = withObject "ApiCard" $ \o ->
        ApiCard <$> o .: "id" <*> o .: "name" <*> o .: "localId"
                <*> o .:? "rarity" <*> o .:? "image" <*> o .:? "category"

data ImportError = ApiFailure Text | InvalidResponse Text | IncompleteCatalog Rarity
    deriving (Show, Eq)

decodeSet :: BL.ByteString -> Either ImportError ApiSet
decodeSet = either (Left . InvalidResponse . T.pack) Right . eitherDecode

decodeCard :: BL.ByteString -> Either ImportError ApiCard
decodeCard = either (Left . InvalidResponse . T.pack) Right . eitherDecode

-- Only known provider labels are mapped; unrecognized values are explicitly skipped.
normalizeRarity :: Text -> Maybe Rarity
normalizeRarity label = lookup (T.toCaseFold (T.strip label)) mappings
  where
    mappings =
        [ ("common", Common), ("uncommon", Uncommon), ("rare", Rare)
        , ("rare holo", Rare), ("holo rare", Rare)
        , ("ultra rare", UltraRare), ("secret rare", UltraRare)
        , ("holo rare v", UltraRare), ("holo rare vmax", UltraRare)
        , ("holo rare vstar", UltraRare), ("radiant rare", UltraRare)
        , ("amazing rare", UltraRare)
        ]

fetchSet :: Text -> IO (Either ImportError ApiSet)
fetchSet set = fetch ("sets/" <> set) decodeSet

fetchCard :: Text -> IO (Either ImportError ApiCard)
fetchCard card = fetch ("cards/" <> card) decodeCard

-- Injectable transport allows offline tests of timeout, HTTP status and JSON errors.
fetchWith :: (String -> IO (Either HttpException (Int, BL.ByteString)))
          -> Text -> (BL.ByteString -> Either ImportError a) -> IO (Either ImportError a)
fetchWith transport path decode = do
    result <- transport ("https://api.tcgdex.net/v2/en/" <> T.unpack path)
    pure $ case result of
        Left exception -> Left (ApiFailure (T.pack (show exception)))
        Right (status, body)
            | status /= 200 -> Left (ApiFailure ("HTTP " <> T.pack (show status)))
            | otherwise -> decode body

fetch :: Text -> (BL.ByteString -> Either ImportError a) -> IO (Either ImportError a)
fetch = fetchWith $ \url -> try $ do
    request <- parseRequest url
    response <- httpLBS (setRequestResponseTimeout (responseTimeoutMicro 10000000) request)
    pure (getResponseStatusCode response, getResponseBody response)

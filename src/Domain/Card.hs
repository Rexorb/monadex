module Domain.Card (CardId(..), Card(..), CardPool, findCard) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Domain.Rarity (Rarity)

newtype CardId = CardId Text deriving (Show, Eq, Ord)

data Card = Card
    { cardId :: CardId
    , cardRarity :: Rarity
    } deriving (Show, Eq)

type CardPool = Map CardId Card

findCard :: CardId -> CardPool -> Maybe Card
findCard = Map.lookup

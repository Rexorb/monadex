{-# LANGUAGE TemplateHaskell #-}
module Domain.Rarity
    ( Rarity(..), Weights(..), defaultWeights, bonusWeights, drawRarity ) where

import Database.Persist.TH (derivePersistField)

data Rarity = Common | Uncommon | Rare | UltraRare
    deriving (Show, Read, Eq, Ord, Enum, Bounded)

derivePersistField "Rarity"

-- Weights are relative integer frequencies; the bonus slot must exclude Common.
newtype Weights = Weights { unWeights :: [(Rarity, Int)] }
    deriving (Show, Eq)

defaultWeights, bonusWeights :: Weights
defaultWeights = Weights [(Common, 60), (Uncommon, 25), (Rare, 10), (UltraRare, 5)]
bonusWeights = Weights [(Uncommon, 25), (Rare, 10), (UltraRare, 5)]

-- The caller supplies a number in [1 .. sum weights]. Invalid input has no result.
drawRarity :: Weights -> Int -> Maybe Rarity
drawRarity (Weights weights) roll
    | roll < 1 || any ((< 0) . snd) weights = Nothing
    | otherwise = select roll weights
  where
    select _ [] = Nothing
    select n ((rarity, weight):rest)
        | n <= weight = Just rarity
        | otherwise = select (n - weight) rest

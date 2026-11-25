module Domain.Error (GameError(..)) where

import Domain.Rarity (Rarity)

data GameError
    = InsufficientBoosters
    | DailyRewardAlreadyClaimed
    | EmptyCardPool Rarity
    | CardNotFound
    | InvalidBooster
    | InvalidPlayerState
    | InvalidWeights
    deriving (Show, Eq)

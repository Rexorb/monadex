module Domain.Booster (BoosterConfig(..), standardConfig, drawBooster, openBooster) where

import Control.Monad (foldM)
import Control.Monad.State.Strict (StateT(..), get, put)
import Data.List (find, foldl')
import qualified Data.Map.Strict as Map
import Domain.Card (Card(..), CardId, CardPool, findCard)
import Domain.Error (GameError(..))
import Domain.Player (PlayerState(..))
import Domain.Rarity (Rarity(..), Weights(..), bonusWeights, defaultWeights, drawRarity)
import System.Random (StdGen, randomR)

data BoosterConfig = BoosterConfig
    { regularWeights :: Weights
    , finalWeights :: Weights
    } deriving (Show, Eq)

standardConfig :: BoosterConfig
standardConfig = BoosterConfig defaultWeights bonusWeights

-- Pure, seeded draw: rarity first, then a card of that rarity. Repeats are allowed.
drawBooster :: BoosterConfig -> CardPool -> StdGen -> Either GameError ([CardId], StdGen)
drawBooster config pool generator = do
    validateWeights config
    mapM_ (\rarity -> if any ((== rarity) . cardRarity) (Map.elems pool)
                       then Right () else Left (EmptyCardPool rarity)) [Common .. UltraRare]
    foldM pick ([], generator) (replicate 5 (regularWeights config) ++ [finalWeights config])
  where
    pick (selected, gen) weights = do
        let total = sum (map snd (unWeights weights))
            (roll, gen1) = randomR (1, total) gen
        rarity <- maybe (Left InvalidWeights) Right (drawRarity weights roll)
        let candidates = [cardId card | card <- Map.elems pool, cardRarity card == rarity]
        case candidates of
            [] -> Left (EmptyCardPool rarity)
            _ -> do
                let (index, gen2) = randomR (0, length candidates - 1) gen1
                chosen <- maybe (Left (EmptyCardPool rarity)) Right (safeIndex index candidates)
                Right (selected ++ [chosen], gen2)

    safeIndex index = fmap snd . find ((== index) . fst) . zip [0 :: Int ..]

validateWeights :: BoosterConfig -> Either GameError ()
validateWeights (BoosterConfig regular final)
    | valid regular [Common .. UltraRare] && valid final [Uncommon .. UltraRare]
      && weight Common final == 0 = Right ()
    | otherwise = Left InvalidWeights
  where
    weight rarity = sum . map snd . filter ((== rarity) . fst) . unWeights
    valid weights rarities = all ((> 0) . (`weight` weights)) rarities
        && all ((>= 0) . snd) (unWeights weights)
        && all (\rarity -> length (filter ((== rarity) . fst) (unWeights weights)) <= 1)
               [Common .. UltraRare]
        && sum (map (toInteger . snd) (unWeights weights)) <= toInteger (maxBound :: Int)

-- This transition never persists data: services must commit its result atomically later.
openBooster :: CardPool -> [CardId] -> StateT PlayerState (Either GameError) [CardId]
openBooster pool cards = do
    player <- get
    if boosterCount player < 0 || any (<= 0) (Map.elems (collection player))
        then failState InvalidPlayerState
        else if boosterCount player == 0 then failState InsufficientBoosters
        else if length cards /= 6 then failState InvalidBooster
        else case traverse (`findCard` pool) cards of
            Nothing -> failState CardNotFound
            Just found -> case reverse found of
                [] -> failState InvalidBooster
                finalCard:_ | cardRarity finalCard == Common -> failState InvalidBooster
                _ -> do
                    let updated = foldl' (\acc key -> Map.insertWith (+) key 1 acc) (collection player) cards
                    put player { boosterCount = boosterCount player - 1, collection = updated }
                    pure cards
  where
    failState failure = StateT (\_ -> Left failure)

module Domain.Player (PlayerState(..), claimDailyReward) where

import Control.Monad.State.Strict (StateT(..), get, put)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Time (Day)
import Domain.Card (CardId)
import Domain.Error (GameError(..))

data PlayerState = PlayerState
    { boosterCount :: Int
    , collection :: Map CardId Int
    , lastClaim :: Maybe Day
    } deriving (Show, Eq)

-- The caller provides the server's local day, never a browser-supplied date.
claimDailyReward :: Day -> StateT PlayerState (Either GameError) ()
claimDailyReward today = do
    player <- get
    if boosterCount player < 0 || any (<= 0) (Map.elems (collection player))
        then stateTFailure InvalidPlayerState
        else case lastClaim player of
            Just previous | previous >= today -> stateTFailure DailyRewardAlreadyClaimed
            _ -> put player { boosterCount = boosterCount player + 1, lastClaim = Just today }

-- Small helper to keep the failure branch explicit without partial functions.
stateTFailure :: GameError -> StateT PlayerState (Either GameError) a
stateTFailure failure = StateT (\_ -> Left failure)

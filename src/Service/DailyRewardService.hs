{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Service.DailyRewardService (grantDailyReward, grantDailyRewardAt, dailyRewardStatus, localDay) where

import Control.Monad.IO.Class (MonadIO, liftIO)
import Control.Monad.State.Strict (runStateT)
import Data.Int (Int64)
import Data.Time (Day, UTCTime, getCurrentTime)
import qualified Data.Time.LocalTime as LocalTime
import Data.Time.LocalTime.TimeZone.Series (TimeZoneSeries, utcToLocalTime')
import Database.Persist (Entity(..), getBy, insert, update, (=.))
import Database.Persist.Sql (SqlPersistT, Single(..), rawSql, toPersistValue)
import Domain.Player (PlayerState(..), claimDailyReward)
import Domain.Error (GameError(..))
import qualified Data.Map.Strict as Map
import Model

localDay :: TimeZoneSeries -> UTCTime -> Day
localDay zone = LocalTime.localDay . utcToLocalTime' zone

-- Reading the status never grants a reward or changes the database.
dailyRewardStatus :: MonadIO m => TimeZoneSeries -> UserId -> SqlPersistT m (Day, Bool)
dailyRewardStatus zone userId = do
    today <- localDay zone <$> liftIO getCurrentTime
    reward <- getBy (UniqueRewardUser userId)
    pure (today, maybe False ((>= today) . dailyRewardLastClaimDate . entityVal) reward)

-- Locking the user row serializes this operation with openings of the same account.
grantDailyReward :: MonadIO m => TimeZoneSeries -> UserId -> SqlPersistT m (Either GameError (Day, Bool))
grantDailyReward zone userId = claimWithClock zone userId (liftIO getCurrentTime)

-- A controlled clock for isolated integration tests; no HTTP route accepts a date.
grantDailyRewardAt :: MonadIO m => TimeZoneSeries -> UTCTime -> UserId -> SqlPersistT m (Either GameError (Day, Bool))
grantDailyRewardAt zone instant userId = claimWithClock zone userId (pure instant)

claimWithClock :: MonadIO m => TimeZoneSeries -> UserId -> SqlPersistT m UTCTime
               -> SqlPersistT m (Either GameError (Day, Bool))
claimWithClock zone userId clock = do
    _locks :: [Single Int64] <- rawSql "SELECT id FROM \"user\" WHERE id = ? FOR UPDATE"
        [toPersistValue userId]
    now <- clock
    let today = localDay zone now
    inventory <- getBy (UniqueInventoryUser userId)
    reward <- getBy (UniqueRewardUser userId)
    case inventory of
        Nothing -> pure (Left InvalidPlayerState)
        Just (Entity inventoryId stored) -> do
            let lastDate = dailyRewardLastClaimDate . entityVal <$> reward
                state = PlayerState (boosterInventoryQuantity stored) Map.empty lastDate
            case runStateT (claimDailyReward today) state of
                Left DailyRewardAlreadyClaimed -> pure (Right (today, False))
                Left failure -> pure (Left failure)
                Right ((), updated) -> do
                    update inventoryId [BoosterInventoryQuantity =. boosterCount updated]
                    case reward of
                        Just (Entity rewardId _) -> update rewardId [DailyRewardLastClaimDate =. today]
                        Nothing -> do
                            _ <- insert (DailyReward userId today)
                            pure ()
                    pure (Right (today, True))

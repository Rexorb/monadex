{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}
module Model where

import Data.Text (Text)
import Data.Time (Day, UTCTime)
import Domain.Rarity (Rarity)
import Control.Monad.IO.Class (MonadIO)
import Database.Persist.Sql (SqlPersistT, rawExecute, runMigration)
import Database.Persist.TH (mkMigrate, mkPersist, persistLowerCase, share, sqlSettings)

share [mkPersist sqlSettings, mkMigrate "migrateAll"] [persistLowerCase|
User
    username Text
    passwordHash Text
    createdAt UTCTime
    UniqueUsername username
    deriving Show
AuthAttempt
    username Text
    failedCount Int
    lastFailedAt UTCTime
    UniqueAuthAttemptUsername username
    deriving Show
Expansion
    externalId Text
    name Text
    logoUrl Text Maybe
    releaseDate Day Maybe
    UniqueExpansionExternal externalId
    deriving Show
Card
    externalId Text
    expansionId ExpansionId
    name Text
    pokemon Text Maybe
    originalRarity Text Maybe
    rarity Rarity
    number Text
    imageUrl Text Maybe
    UniqueCardExternal externalId
    deriving Show
Collection
    userId UserId
    cardId CardId
    quantity Int
    UniqueCollection userId cardId
    deriving Show
BoosterInventory
    userId UserId
    quantity Int
    UniqueInventoryUser userId
    deriving Show
DailyReward
    userId UserId
    lastClaimDate Day
    UniqueRewardUser userId
    deriving Show
BoosterOpening
    userId UserId
    openedAt UTCTime
    deriving Show
BoosterOpeningCard
    openingId BoosterOpeningId
    cardId CardId
    position Int
    UniqueOpeningPosition openingId position
    deriving Show
|]

-- Used by the server and isolated integration tests so both get the same constraints.
migrateMonadex :: MonadIO m => SqlPersistT m ()
migrateMonadex = do
    runMigration migrateAll
    rawExecute "DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'collection_quantity_positive' AND conrelid = 'collection'::regclass) THEN ALTER TABLE collection ADD CONSTRAINT collection_quantity_positive CHECK (quantity > 0); END IF; IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'inventory_quantity_nonnegative' AND conrelid = 'booster_inventory'::regclass) THEN ALTER TABLE booster_inventory ADD CONSTRAINT inventory_quantity_nonnegative CHECK (quantity >= 0); END IF; IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'card_rarity_valid' AND conrelid = 'card'::regclass) THEN ALTER TABLE card ADD CONSTRAINT card_rarity_valid CHECK (rarity IN ('Common', 'Uncommon', 'Rare', 'UltraRare')); END IF; IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'opening_card_position_valid' AND conrelid = 'booster_opening_card'::regclass) THEN ALTER TABLE booster_opening_card ADD CONSTRAINT opening_card_position_valid CHECK (position BETWEEN 1 AND 6); END IF; END $$" []

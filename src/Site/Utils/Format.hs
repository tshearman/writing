{-# LANGUAGE OverloadedStrings #-}

module Site.Utils.Format
  ( formatDay,
    getYear,
  )
where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, defaultTimeLocale, formatTime, toGregorian)

-- | Format a Day as a human-readable date string
formatDay :: Day -> Text
formatDay = T.pack . formatTime defaultTimeLocale "%B %e, %Y"

-- | Extract the year from a Day
getYear :: Day -> Integer
getYear day =
  let (year, _, _) = toGregorian day
   in year

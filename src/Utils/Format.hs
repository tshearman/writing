{-# LANGUAGE TemplateHaskell #-}

module Utils.Format (dateFormat, formatDay, getYear) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, defaultTimeLocale, formatTime, toGregorian)
import Utils.TH (jsonField)

dateFormat :: String
dateFormat = $(jsonField "config/formats.json" "dateFormat")

formatDay :: Day -> Text
formatDay = T.pack . formatTime defaultTimeLocale dateFormat

getYear :: Day -> Integer
getYear day =
  let (year, _, _) = toGregorian day
   in year

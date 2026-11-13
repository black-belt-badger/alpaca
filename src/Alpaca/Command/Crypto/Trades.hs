module Alpaca.Command.Crypto.Trades
  ( CryptoTradesCommand (..)
  ) where

import Alpaca.Command.Crypto.Bars
  ( BarsFormat
  , BarsInstant
  , BarsSort
  , CryptoLocation
  )
import Data.Text (Text)

-- | Historical trades share Alpaca's validated crypto filters with bars,
-- but do not accept a timeframe: every trade is an individual execution.
data CryptoTradesCommand = CryptoTradesCommand
  { cryptoTradesSymbols :: [Text]
  , cryptoTradesLocation :: CryptoLocation
  , cryptoTradesStart :: Maybe BarsInstant
  , cryptoTradesEnd :: Maybe BarsInstant
  , cryptoTradesLimit :: Int
  , cryptoTradesSort :: BarsSort
  , cryptoTradesMaxPages :: Int
  , cryptoTradesPageToken :: Maybe Text
  , cryptoTradesFormat :: BarsFormat
  , cryptoTradesOutput :: Maybe FilePath
  }
  deriving (Eq, Show)

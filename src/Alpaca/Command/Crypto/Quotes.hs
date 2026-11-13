module Alpaca.Command.Crypto.Quotes
  ( CryptoQuotesCommand (..)
  ) where

import Alpaca.Command.Crypto.Bars
  ( BarsFormat
  , BarsInstant
  , BarsSort
  , CryptoLocation
  )
import Data.Text (Text)

-- | Historical best bid/ask quotes share validated crypto market-data
-- parameters with trades; each quote is an event, with no timeframe.
data CryptoQuotesCommand = CryptoQuotesCommand
  { cryptoQuotesSymbols :: [Text]
  , cryptoQuotesLocation :: CryptoLocation
  , cryptoQuotesStart :: Maybe BarsInstant
  , cryptoQuotesEnd :: Maybe BarsInstant
  , cryptoQuotesLimit :: Int
  , cryptoQuotesSort :: BarsSort
  , cryptoQuotesMaxPages :: Int
  , cryptoQuotesPageToken :: Maybe Text
  , cryptoQuotesFormat :: BarsFormat
  , cryptoQuotesOutput :: Maybe FilePath
  }
  deriving (Eq, Show)

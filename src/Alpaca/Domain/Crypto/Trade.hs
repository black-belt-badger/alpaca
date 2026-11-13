{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.Crypto.Trade
  ( CryptoTrade (..)
  , CryptoTradesPage (..)
  , decodeCryptoTradesPage
  , tradeToJson
  , forEachTrade
  , tradeCount
  ) where

import Control.Monad (forM_)
import Data.Aeson
  ( FromJSON (..)
  , Value
  , eitherDecodeStrict'
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.=)
  )
import Data.ByteString (ByteString)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Scientific (Scientific)
import Data.Text (Text)
import qualified Data.Text as Text

-- | No floating point conversions: price and size are exact decimal values.
-- The exchange timestamp is retained verbatim, including nanoseconds.
-- Trade IDs are unbounded integers and taker side may be missing or null.
data CryptoTrade = CryptoTrade
  { tradeId :: Integer
  , tradePrice :: Scientific
  , tradeSize :: Scientific
  , tradeTimestamp :: Text
  , tradeTakerSide :: Maybe Text
  }
  deriving (Eq, Show)

instance FromJSON CryptoTrade where
  parseJSON = withObject "CryptoTrade" $ \o ->
    CryptoTrade
      <$> o .: "i"
      <*> o .: "p"
      <*> o .: "s"
      <*> o .: "t"
      <*> o .:? "tks"

-- | Per-symbol trades plus original page, including future API properties.
data CryptoTradesPage = CryptoTradesPage
  { pageTrades :: Map Text [CryptoTrade]
  , pageNextToken :: Maybe Text
  , pageOriginal :: Value
  }
  deriving (Eq, Show)

instance FromJSON CryptoTradesPage where
  parseJSON value = withObject "CryptoTradesPage" (\o -> do
    trades <- o .: "trades"
    token <- o .:? "next_page_token"
    pure (CryptoTradesPage trades (token >>= nonempty) value)) value
    where
      nonempty token
        | Text.null token = Nothing
        | otherwise = Just token

decodeCryptoTradesPage :: ByteString -> Either String CryptoTradesPage
decodeCryptoTradesPage = eitherDecodeStrict'

-- | All known trade fields plus the symbol in a single JSONL record.
-- For additional upstream fields, use the JSON page-envelope export.
tradeToJson :: Text -> CryptoTrade -> Value
tradeToJson symbol trade =
  object
    [ "symbol" .= symbol
    , "i" .= tradeId trade
    , "p" .= tradePrice trade
    , "s" .= tradeSize trade
    , "t" .= tradeTimestamp trade
    , "tks" .= tradeTakerSide trade
    ]

-- | Visit one page without allocating a flattened list of trades.
forEachTrade :: Monad m => (Text -> CryptoTrade -> m ()) -> CryptoTradesPage -> m ()
forEachTrade action page =
  forM_ (Map.toAscList (pageTrades page)) $ \(symbol, trades) ->
    forM_ trades (action symbol)

tradeCount :: CryptoTradesPage -> Int
tradeCount = sum . map length . Map.elems . pageTrades

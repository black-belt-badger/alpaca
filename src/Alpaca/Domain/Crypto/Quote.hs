{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.Crypto.Quote
  ( CryptoQuote (..)
  , CryptoQuotesPage (..)
  , decodeCryptoQuotesPage
  , quoteToJson
  , forEachQuote
  , quoteCount
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

-- | Best bid and ask at a precise instant. Alpaca defines sizes in the
-- base asset, without a lot multiplier. Scientific retains arbitrary
-- decimal precision; timestamp text retains nanosecond accuracy.
data CryptoQuote = CryptoQuote
  { quoteAskPrice :: Scientific
  , quoteAskSize :: Scientific
  , quoteBidPrice :: Scientific
  , quoteBidSize :: Scientific
  , quoteTimestamp :: Text
  }
  deriving (Eq, Show)

instance FromJSON CryptoQuote where
  parseJSON = withObject "CryptoQuote" $ \o ->
    CryptoQuote
      <$> o .: "ap"
      <*> o .: "as"
      <*> o .: "bp"
      <*> o .: "bs"
      <*> o .: "t"

-- | Original API page is preserved, including provider extension fields
-- and unrecognized quote properties, for complete page-envelope JSON.
data CryptoQuotesPage = CryptoQuotesPage
  { pageQuotes :: Map Text [CryptoQuote]
  , pageNextToken :: Maybe Text
  , pageOriginal :: Value
  }
  deriving (Eq, Show)

instance FromJSON CryptoQuotesPage where
  parseJSON value = withObject "CryptoQuotesPage" (\o -> do
    quotes <- o .: "quotes"
    token <- o .:? "next_page_token"
    pure (CryptoQuotesPage quotes (token >>= nonempty) value)) value
    where
      nonempty token
        | Text.null token = Nothing
        | otherwise = Just token

decodeCryptoQuotesPage :: ByteString -> Either String CryptoQuotesPage
decodeCryptoQuotesPage = eitherDecodeStrict'

-- | A single JSONL quote keeps exact values and the source symbol.
-- Unrecognized provider fields are retained in JSON page exports.
quoteToJson :: Text -> CryptoQuote -> Value
quoteToJson symbol quote =
  object
    [ "symbol" .= symbol
    , "ap" .= quoteAskPrice quote
    , "as" .= quoteAskSize quote
    , "bp" .= quoteBidPrice quote
    , "bs" .= quoteBidSize quote
    , "t" .= quoteTimestamp quote
    ]

-- | Traverse each page without materializing a flattened cross-symbol list.
forEachQuote :: Monad m => (Text -> CryptoQuote -> m ()) -> CryptoQuotesPage -> m ()
forEachQuote action page =
  forM_ (Map.toAscList (pageQuotes page)) $ \(symbol, quotes) ->
    forM_ quotes (action symbol)

quoteCount :: CryptoQuotesPage -> Int
quoteCount = sum . map length . Map.elems . pageQuotes

{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.Crypto.Bar
  ( CryptoBar (..)
  , CryptoBarsPage (..)
  , decodeCryptoBarsPage
  , flattenBars
  , encodeBarsJsonl
  , encodePagesJson
  , barCount
  ) where

import Data.Aeson
  ( FromJSON (..)
  , Value (..)
  , eitherDecodeStrict'
  , encode
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.=)
  )
import Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as Lazy
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Scientific (Scientific)
import Data.Text (Text)
import qualified Data.Text as Text

-- | Scientific retains the exact numeric decimal value supplied by JSON.
-- Timestamps remain Text so fractional nanoseconds are never discarded.
data CryptoBar = CryptoBar
  { barTimestamp :: Text
  , barOpen :: Scientific
  , barHigh :: Scientific
  , barLow :: Scientific
  , barClose :: Scientific
  , barVolume :: Scientific
  , barTradeCount :: Maybe Integer
  , barVwap :: Maybe Scientific
  }
  deriving (Eq, Show)

instance FromJSON CryptoBar where
  parseJSON = withObject "CryptoBar" $ \o ->
    CryptoBar
      <$> o .: "t"
      <*> o .: "o"
      <*> o .: "h"
      <*> o .: "l"
      <*> o .: "c"
      <*> o .: "v"
      <*> o .:? "n"
      <*> o .:? "vw"

-- | JSONL contains one line per bar with its symbol, and all known fields.
barToJson :: (Text, CryptoBar) -> Value
barToJson (symbol, bar) =
  object
    [ "symbol" .= symbol
      , "t" .= barTimestamp bar
      , "o" .= barOpen bar
      , "h" .= barHigh bar
      , "l" .= barLow bar
      , "c" .= barClose bar
      , "v" .= barVolume bar
      , "n" .= barTradeCount bar
      , "vw" .= barVwap bar
    ]

-- | Retain the original JSON Value for lossless *data* round trips in JSON
-- export, including fields Kirke does not yet interpret.
data CryptoBarsPage = CryptoBarsPage
  { pageBars :: Map Text [CryptoBar]
  , pageNextToken :: Maybe Text
  , pageOriginal :: Value
  }
  deriving (Eq, Show)

instance FromJSON CryptoBarsPage where
  parseJSON value = withObject "CryptoBarsPage" (\o -> do
    bars <- o .: "bars"
    token <- o .:? "next_page_token"
    pure (CryptoBarsPage bars (token >>= nonempty) value)) value
    where
      nonempty token
        | Text.null token = Nothing
        | otherwise = Just token

decodeCryptoBarsPage :: ByteString -> Either String CryptoBarsPage
decodeCryptoBarsPage = eitherDecodeStrict'

-- | Preserve page order, then provider-symbol ordering within each page.
flattenBars :: [CryptoBarsPage] -> [(Text, CryptoBar)]
flattenBars = concatMap (concatMap expand . Map.toAscList . pageBars)
  where
    expand (symbol, bars) = map (\bar -> (symbol, bar)) bars

barCount :: [CryptoBarsPage] -> Int
barCount = length . flattenBars

-- | Stable JSON output schema: {"pages":[original API pages], "next_page_token":...}.
-- A non-null last token means the caller stopped before the last provider page.
encodePagesJson :: [CryptoBarsPage] -> ByteString
encodePagesJson pages =
  Lazy.toStrict (encode (object
    [ "pages" .= map pageOriginal pages
    , "next_page_token" .= case reverse pages of
        [] -> Nothing
        (lastPage : _) -> pageNextToken lastPage
    ]))

encodeBarsJsonl :: [CryptoBarsPage] -> ByteString
encodeBarsJsonl =
  Lazy.toStrict . mconcat . map (\bar -> encode (barToJson bar) <> "\n") . flattenBars

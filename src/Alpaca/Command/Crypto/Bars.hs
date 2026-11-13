{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Crypto.Bars
  ( CryptoLocation (..)
  , BarsTimeframe
  , BarsInstant
  , BarsSort (..)
  , BarsFormat (..)
  , CryptoBarsCommand (..)
  , locationParameter
  , timeframeParameter
  , instantParameter
  , sortParameter
  , parseLocation
  , parseSymbols
  , parseTimeframe
  , parseInstant
  , parsePageLimit
  , parseMaxPages
  , parsePageToken
  , parseSort
  , parseBarsFormat
  , validateDateRange
  ) where

import Data.Char (isAsciiUpper, isSpace)
import Data.List (isSuffixOf)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (Day, UTCTime (..), ZonedTime, zonedTimeToUTC)
import Data.Time.Format (defaultTimeLocale, parseTimeM)
import Text.Read (readMaybe)

-- | Alpaca's documented historical-crypto locations (not a free-form URL).
data CryptoLocation = Us | Us1 | Us2 | Eu1 | Bs1
  deriving (Eq, Show)

newtype BarsTimeframe = BarsTimeframe Text deriving (Eq, Show)

-- | Keep original RFC3339 input (including nanoseconds) for the HTTP query,
-- and its UTC equivalent for cross-offset interval validation.
data BarsInstant = BarsInstant Text UTCTime deriving (Eq, Show)

data BarsSort = BarsAsc | BarsDesc deriving (Eq, Show)

data BarsFormat = BarsJson | BarsJsonl deriving (Eq, Show)

data CryptoBarsCommand = CryptoBarsCommand
  { cryptoBarsSymbols :: [Text]
  , cryptoBarsLocation :: CryptoLocation
  , cryptoBarsTimeframe :: BarsTimeframe
  , cryptoBarsStart :: Maybe BarsInstant
  , cryptoBarsEnd :: Maybe BarsInstant
  , cryptoBarsLimit :: Int
  , cryptoBarsSort :: BarsSort
  , cryptoBarsMaxPages :: Int
  , cryptoBarsPageToken :: Maybe Text
  , cryptoBarsFormat :: BarsFormat
  , cryptoBarsOutput :: Maybe FilePath
  }
  deriving (Eq, Show)

locationParameter :: CryptoLocation -> String
locationParameter Us = "us"
locationParameter Us1 = "us-1"
locationParameter Us2 = "us-2"
locationParameter Eu1 = "eu-1"
locationParameter Bs1 = "bs-1"

parseLocation :: String -> Either String CryptoLocation
parseLocation "us" = Right Us
parseLocation "us-1" = Right Us1
parseLocation "us-2" = Right Us2
parseLocation "eu-1" = Right Eu1
parseLocation "bs-1" = Right Bs1
parseLocation _ = Left "Expected crypto location: us, us-1, us-2, eu-1, or bs-1"

parseSymbols :: String -> Either String [Text]
parseSymbols input =
  let symbols = map (Text.pack . trim) (splitCommas input)
   in if length symbols <= 30 && all validSymbol symbols
        then Right symbols
        else Left "Expected 1-30 comma-separated crypto pairs, e.g. BTC/USD,ETH/USD"
  where
    validSymbol symbol =
      case Text.splitOn "/" symbol of
        [base, quote] ->
          validPart base && validPart quote
        _ -> False
    validPart part =
      not (Text.null part)
        && Text.all (\c -> isAsciiUpper c || (c >= '0' && c <= '9')) part

splitCommas :: String -> [String]
splitCommas input =
  case break (== ',') input of
    (part, []) -> [part]
    (part, _ : rest) -> part : splitCommas rest

trim :: String -> String
trim = dropWhile isSpace . reverse . dropWhile isSpace . reverse

timeframeParameter :: BarsTimeframe -> Text
timeframeParameter (BarsTimeframe value) = value

parseTimeframe :: String -> Either String BarsTimeframe
parseTimeframe input
  | input `elem` ["1Day", "1D", "1Week", "1W"] = Right (BarsTimeframe (Text.pack input))
  | valid "Min" [1 .. 59] || valid "T" [1 .. 59]
      || valid "Hour" [1 .. 23] || valid "H" [1 .. 23]
      || valid "Month" [1, 2, 3, 4, 6, 12] || valid "M" [1, 2, 3, 4, 6, 12] =
      Right (BarsTimeframe (Text.pack input))
  | otherwise = Left "Expected Alpaca timeframe, e.g. 1Min, 5Min, 1Hour, 1Day, 1Week, 3Month"
  where
    valid suffix allowed
      | suffix `isSuffixOf` input =
          let digits = take (length input - length suffix) input
           in case readMaybe digits :: Maybe Int of
                Just n -> n `elem` allowed && show n == digits
                Nothing -> False
      | otherwise = False

instantParameter :: BarsInstant -> Text
instantParameter (BarsInstant value _) = value

parseInstant :: String -> Either String BarsInstant
parseInstant input =
  case parseTimeM True defaultTimeLocale "%Y-%m-%d" input :: Maybe Day of
    Just day -> Right (BarsInstant (Text.pack input) (UTCTime day 0))
    Nothing ->
      let normalized =
            if "Z" `isSuffixOf` input
              then take (length input - 1) input <> "+0000"
              else input
       in case parseTimeM True defaultTimeLocale "%Y-%m-%dT%H:%M:%S%Q%Ez" normalized :: Maybe ZonedTime of
            Just instant -> Right (BarsInstant (Text.pack input) (zonedTimeToUTC instant))
            Nothing -> Left "Expected YYYY-MM-DD or RFC3339 timestamp (with timezone)"

validateDateRange :: Maybe BarsInstant -> Maybe BarsInstant -> Either String ()
validateDateRange (Just (BarsInstant _ start)) (Just (BarsInstant _ end))
  | start > end = Left "--start must not be later than --end"
validateDateRange _ _ = Right ()

parseBounded :: String -> Int -> Int -> String -> Either String Int
parseBounded name lower upper input
  | not (null input) && all (\c -> c >= '0' && c <= '9') input =
      case readMaybe input of
        Just n | n >= lower && n <= upper -> Right n
        _ -> Left message
  | otherwise = Left message
  where
    message = name <> " must be between " <> show lower <> " and " <> show upper

parsePageLimit :: String -> Either String Int
parsePageLimit = parseBounded "Page limit" 1 10000

parseMaxPages :: String -> Either String Int
parseMaxPages = parseBounded "Maximum pages" 1 20

-- | Page tokens are opaque. Reject empty, whitespace/control chars and huge
-- inputs; percent-encoding is handled by the HTTP library, not string joins.
parsePageToken :: String -> Either String Text
parsePageToken token
  | not (null token) && length token <= 2048
      && all (\c -> c >= '!' && c <= '~') token =
      Right (Text.pack token)
  | otherwise = Left "Expected a nonempty printable page token (up to 2048 bytes)"

sortParameter :: BarsSort -> Text
sortParameter BarsAsc = "asc"
sortParameter BarsDesc = "desc"

parseSort :: String -> Either String BarsSort
parseSort "asc" = Right BarsAsc
parseSort "desc" = Right BarsDesc
parseSort _ = Left "Expected asc or desc"

parseBarsFormat :: String -> Either String BarsFormat
parseBarsFormat "json" = Right BarsJson
parseBarsFormat "jsonl" = Right BarsJsonl
parseBarsFormat _ = Left "Expected json or jsonl"

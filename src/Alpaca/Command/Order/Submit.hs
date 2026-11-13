{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Order.Submit
  ( SubmitCommand (..)
  , SubmitSymbol
  , SubmitAmount
  , ClientOrderId
  , SubmitSide (..)
  , SubmitKind (..)
  , SubmitTimeInForce (..)
  , PreparedOrder
  , parseSubmitSymbol
  , parseSubmitAmount
  , parseClientOrderId
  , parseSubmitSide
  , parseSubmitKind
  , parseSubmitTimeInForce
  , prepareOrder
  , submittedOrderBody
  , preparedPairValue
  , preparedClientIdValue
  ) where

import Alpaca.Command.Crypto.Bars (parseSymbols)
import Data.Aeson (ToJSON (..), encode, object, (.=))
import qualified Data.ByteString.Lazy as Lazy
import Data.Char (isAsciiUpper)
import Data.Text (Text)
import qualified Data.Text as Text

newtype SubmitSymbol = SubmitSymbol Text deriving (Eq, Show)
newtype SubmitAmount = SubmitAmount Text deriving (Eq, Show)
newtype ClientOrderId = ClientOrderId Text deriving (Eq, Show)

data SubmitSide = SubmitBuy | SubmitSell deriving (Eq, Show)
data SubmitKind = SubmitMarket | SubmitLimit deriving (Eq, Show)
data SubmitTimeInForce = SubmitGtc | SubmitIoc deriving (Eq, Show)

data SubmitCommand = SubmitCommand
  { submitSymbol :: SubmitSymbol
  , submitSide :: SubmitSide
  , submitKind :: SubmitKind
  , submitTimeInForce :: SubmitTimeInForce
  , submitQuantity :: Maybe SubmitAmount
  , submitNotional :: Maybe SubmitAmount
  , submitLimitPrice :: Maybe SubmitAmount
  , submitClientOrderId :: ClientOrderId
  , submitConfirmed :: Bool
  , submitOutput :: Maybe FilePath
  } deriving (Eq, Show)

-- | Only 'prepareOrder' can create this credential-free POST payload.
data PreparedOrder = PreparedOrder
  { preparedSymbol :: SubmitSymbol
  , preparedSide :: SubmitSide
  , preparedKind :: SubmitKind
  , preparedTimeInForce :: SubmitTimeInForce
  , preparedQuantity :: Maybe SubmitAmount
  , preparedNotional :: Maybe SubmitAmount
  , preparedLimitPrice :: Maybe SubmitAmount
  , preparedClientOrderId :: ClientOrderId
  } deriving (Eq, Show)

-- | Exactly one canonical crypto pair; never accept commas or URL fragments.
parseSubmitSymbol :: String -> Either String SubmitSymbol
parseSubmitSymbol raw =
  case parseSymbols raw of
    Right [symbol]
      | validSymbol (Text.unpack symbol) -> Right (SubmitSymbol symbol)
    _ -> Left "Expected one crypto pair, e.g. BTC/USD (not a comma-separated list)"
  where
    validSymbol value =
      case break (== '/') value of
        (base, '/' : quote) -> not (null base) && not (null quote)
          && all validChar (base <> quote)
        _ -> False
    validChar c = isAsciiUpper c || (c >= '0' && c <= '9')

-- | Positive decimal supplied as exact ASCII spelling, never as Double.
-- Min order size and increments are asset-specific and enforced by Alpaca.
parseSubmitAmount :: String -> Either String SubmitAmount
parseSubmitAmount raw =
  case break (== '.') raw of
    (whole, fraction)
      | not (null raw) && length raw <= 64
        && not (null whole) && all asciiDigit whole
        && case fraction of
          [] -> True
          '.' : digits -> not (null digits) && length digits <= 9 && all asciiDigit digits
          _ -> False
        && any (\digit -> digit >= '1' && digit <= '9') raw ->
          Right (SubmitAmount (Text.pack raw))
    _ -> Left "Expected a positive decimal (up to 9 fractional digits, no exponent)"
  where
    asciiDigit c = c >= '0' && c <= '9'

-- | Stable caller-controlled identifier, at most 128 safe ASCII bytes.
-- A repeated client-order ID is useful for investigation, not a guarantee
-- of idempotency. Never silently retry an uncertain POST.
parseClientOrderId :: String -> Either String ClientOrderId
parseClientOrderId raw
  | not (null raw) && length raw <= 128 && all valid raw =
      Right (ClientOrderId (Text.pack raw))
  | otherwise =
      Left "Expected a nonempty client order ID (max 128 ASCII letters, digits, '.', '-', '_' or ':')"
  where
    valid c = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
      || (c >= '0' && c <= '9') || elem c (".-_:" :: String)

parseSubmitSide :: String -> Either String SubmitSide
parseSubmitSide "buy" = Right SubmitBuy
parseSubmitSide "sell" = Right SubmitSell
parseSubmitSide _ = Left "Expected buy or sell"

parseSubmitKind :: String -> Either String SubmitKind
parseSubmitKind "market" = Right SubmitMarket
parseSubmitKind "limit" = Right SubmitLimit
parseSubmitKind _ = Left "Expected market or limit"

parseSubmitTimeInForce :: String -> Either String SubmitTimeInForce
parseSubmitTimeInForce "gtc" = Right SubmitGtc
parseSubmitTimeInForce "ioc" = Right SubmitIoc
parseSubmitTimeInForce _ = Left "Crypto orders support gtc or ioc"

-- | Validation precedes any credential loading or network access.
prepareOrder :: SubmitCommand -> Either String PreparedOrder
prepareOrder options
  | submitQuantity options == Nothing && submitNotional options == Nothing =
      Left "Exactly one of --qty or --notional is required"
  | submitQuantity options /= Nothing && submitNotional options /= Nothing =
      Left "--qty and --notional cannot be combined"
  | submitKind options == SubmitMarket && submitLimitPrice options /= Nothing =
      Left "--limit-price is only allowed for limit orders"
  | submitKind options == SubmitLimit && submitLimitPrice options == Nothing =
      Left "Limit orders require --limit-price"
  | submitKind options == SubmitLimit && submitNotional options /= Nothing =
      Left "Limit orders require --qty; --notional is supported only for market orders"
  | maybe False tooManyUsdNotionalDecimals (submitNotional options) =
      Left "USD-quoted crypto notional supports at most 2 decimal places"
  | not (submitConfirmed options) && submitOutput options /= Nothing =
      Left "--out requires --confirm; dry runs do not write response files"
  | otherwise = Right PreparedOrder
      { preparedSymbol = submitSymbol options
      , preparedSide = submitSide options
      , preparedKind = submitKind options
      , preparedTimeInForce = submitTimeInForce options
      , preparedQuantity = submitQuantity options
      , preparedNotional = submitNotional options
      , preparedLimitPrice = submitLimitPrice options
      , preparedClientOrderId = submitClientOrderId options
      }
  where
    tooManyUsdNotionalDecimals (SubmitAmount amount) =
      Text.isSuffixOf "/USD" (rawSymbol (submitSymbol options))
        && Text.length (Text.drop 1 (Text.dropWhile (/= '.') amount)) > 2

instance ToJSON PreparedOrder where
  toJSON order = object
    ( [ "symbol" .= preparedPairValue order
      , "side" .= sideValue (preparedSide order)
      , "type" .= kindValue (preparedKind order)
      , "time_in_force" .= tifValue (preparedTimeInForce order)
      , "client_order_id" .= preparedClientIdValue order
      ]
      <> maybe [] (\(SubmitAmount qty) -> ["qty" .= qty]) (preparedQuantity order)
      <> maybe [] (\(SubmitAmount value) -> ["notional" .= value]) (preparedNotional order)
      <> maybe [] (\(SubmitAmount value) -> ["limit_price" .= value]) (preparedLimitPrice order)
    )

submittedOrderBody :: PreparedOrder -> Lazy.ByteString
submittedOrderBody = encode

preparedPairValue :: PreparedOrder -> Text
preparedPairValue = rawSymbol . preparedSymbol

preparedClientIdValue :: PreparedOrder -> Text
preparedClientIdValue = rawClientId . preparedClientOrderId

rawSymbol :: SubmitSymbol -> Text
rawSymbol (SubmitSymbol symbol) = symbol

rawClientId :: ClientOrderId -> Text
rawClientId (ClientOrderId ident) = ident

sideValue :: SubmitSide -> Text
sideValue SubmitBuy = "buy"
sideValue SubmitSell = "sell"

kindValue :: SubmitKind -> Text
kindValue SubmitMarket = "market"
kindValue SubmitLimit = "limit"

tifValue :: SubmitTimeInForce -> Text
tifValue SubmitGtc = "gtc"
tifValue SubmitIoc = "ioc"

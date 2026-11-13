{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Orders
  ( OrderStatus (..)
  , OrderDirection (..)
  , OrderSideFilter (..)
  , OrderAssetClass (..)
  , OrdersCommand (..)
  , orderStatusParameter
  , orderDirectionParameter
  , orderSideParameter
  , orderAssetClassParameter
  , parseOrderStatus
  , parseOrderDirection
  , parseOrderLimit
  , parseOrderSymbols
  , parseOrderSide
  , parseOrderAssetClasses
  , parseOrderTimestamp
  , validateOrdersCommand
  ) where

import Alpaca.Command.Assets (AssetClass, assetClassParameter, parseAssetClass)
import Alpaca.Command.Crypto.Bars (BarsInstant, parseInstant, validateDateRange)
import Alpaca.Command.Order (OrderId)
import Data.ByteString (ByteString)
import Data.Char (isAsciiUpper, isSpace)
import Data.List (nub)
import Text.Read (readMaybe)

-- | Query filters, not the full set of order states in a response.
data OrderStatus = OrdersOpen | OrdersClosed | OrdersAll
  deriving (Eq, Show)

data OrderDirection = Asc | Desc
  deriving (Eq, Show)

data OrderSideFilter = Buy | Sell
  deriving (Eq, Show)

-- | The list endpoint accepts 'all' in addition to all asset classes.
data OrderAssetClass = OrderAssetClass AssetClass | OrderAllClasses
  deriving (Eq, Show)

data OrdersCommand = OrdersCommand
  { ordersStatus :: OrderStatus
  , ordersLimit :: Maybe Int
  , ordersSymbols :: Maybe [String]
  , ordersDirection :: OrderDirection
  , ordersOutput :: Maybe FilePath
  , ordersAfter :: Maybe BarsInstant
  , ordersUntil :: Maybe BarsInstant
  , ordersNested :: Bool
  , ordersSide :: Maybe OrderSideFilter
  , ordersAssetClasses :: Maybe [OrderAssetClass]
  , ordersBeforeOrderId :: Maybe OrderId
  , ordersAfterOrderId :: Maybe OrderId
  }
  deriving (Eq, Show)

orderStatusParameter :: OrderStatus -> ByteString
orderStatusParameter OrdersOpen = "open"
orderStatusParameter OrdersClosed = "closed"
orderStatusParameter OrdersAll = "all"

orderDirectionParameter :: OrderDirection -> ByteString
orderDirectionParameter Asc = "asc"
orderDirectionParameter Desc = "desc"

orderSideParameter :: OrderSideFilter -> ByteString
orderSideParameter Buy = "buy"
orderSideParameter Sell = "sell"

orderAssetClassParameter :: OrderAssetClass -> ByteString
orderAssetClassParameter (OrderAssetClass known) = assetClassParameter known
orderAssetClassParameter OrderAllClasses = "all"

parseOrderStatus :: String -> Either String OrderStatus
parseOrderStatus "open" = Right OrdersOpen
parseOrderStatus "closed" = Right OrdersClosed
parseOrderStatus "all" = Right OrdersAll
parseOrderStatus _ = Left "Expected open, closed, or all"

parseOrderDirection :: String -> Either String OrderDirection
parseOrderDirection "asc" = Right Asc
parseOrderDirection "desc" = Right Desc
parseOrderDirection _ = Left "Expected asc or desc"

parseOrderSide :: String -> Either String OrderSideFilter
parseOrderSide "buy" = Right Buy
parseOrderSide "sell" = Right Sell
parseOrderSide _ = Left "Order side must be buy or sell"

-- | The API expects submitted-at timestamps with an explicit timezone.
-- Reuse our RFC3339 parser, disallowing date-only market-data shorthand.
parseOrderTimestamp :: String -> Either String BarsInstant
parseOrderTimestamp value
  | 'T' `elem` value = parseInstant value
  | otherwise = Left "Order timestamp must be RFC3339 with timezone"

-- | Alpaca's documented inclusive range is 1..500.
parseOrderLimit :: String -> Either String Int
parseOrderLimit input
  | not (null input) && all (\c -> c >= '0' && c <= '9') input =
      case readMaybe input of
        Just count | count >= 1 && count <= 500 -> Right count
        _ -> Left "Order limit must be between 1 and 500"
  | otherwise = Left "Order limit must be between 1 and 500"

-- | For trading-order filters Alpaca expects BTCUSD, not BTC/USD.
-- Reject empty or ambiguous symbols before performing any network IO.
parseOrderSymbols :: String -> Either String [String]
parseOrderSymbols input =
  let symbols = map strip (splitCommas input)
   in if not (null symbols) && all validSymbol symbols
        then Right symbols
        else Left "Expected comma-separated symbols such as BTCUSD,ETHUSD,AAPL"

validSymbol :: String -> Bool
validSymbol symbol =
  not (null symbol)
    && all (\c -> isAsciiUpper c || (c >= '0' && c <= '9') || c == '.' || c == '-') symbol

-- | A closed set of provider query values; every supplied CSV member is
-- sent, while duplicate, empty, or unsupported members cause an error.
parseOrderAssetClasses :: String -> Either String [OrderAssetClass]
parseOrderAssetClasses input = do
  let pieces = map strip (splitCommas input)
  if any null pieces
    then Left "Expected nonempty comma-separated asset classes"
    else do
      classes <- traverse parseClass pieces
      if length classes == length (nub classes)
        then if OrderAllClasses `elem` classes && length classes > 1
          then Left "asset_class=all cannot be combined with individual classes"
          else Right classes
        else Left "Duplicate asset classes are not allowed"
  where
    parseClass "all" = Right OrderAllClasses
    parseClass value = OrderAssetClass <$> parseAssetClass value

-- | Order-ID anchor pagination cannot be mixed with timestamp bounds,
-- and the two anchors are mutually exclusive. Detect this before credentials.
validateOrdersCommand :: OrdersCommand -> Either String OrdersCommand
validateOrdersCommand options = do
  _ <- validateDateRange (ordersAfter options) (ordersUntil options)
  let hasAnchor = maybe False (const True) (ordersBeforeOrderId options)
               || maybe False (const True) (ordersAfterOrderId options)
      hasTime = maybe False (const True) (ordersAfter options)
             || maybe False (const True) (ordersUntil options)
  if hasAnchor && hasTime
    then Left "Order-ID pagination cannot be combined with --after or --until"
    else if maybe False (const True) (ordersBeforeOrderId options)
          && maybe False (const True) (ordersAfterOrderId options)
      then Left "--before-order-id and --after-order-id are mutually exclusive"
      else if ordersAssetClasses options == Just []
        then Left "asset_class filter must not be empty"
        else Right options

strip :: String -> String
strip = dropWhile isSpace . reverse . dropWhile isSpace . reverse

splitCommas :: String -> [String]
splitCommas input =
  case break (== ',') input of
    (part, []) -> [part]
    (part, _ : rest) -> part : splitCommas rest

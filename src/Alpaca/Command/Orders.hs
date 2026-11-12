{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Orders
  ( OrderStatus (..)
  , OrderDirection (..)
  , OrdersCommand (..)
  , orderStatusParameter
  , orderDirectionParameter
  , parseOrderStatus
  , parseOrderDirection
  , parseOrderLimit
  , parseOrderSymbols
  ) where

import Data.ByteString (ByteString)
import Data.Char (isAsciiUpper, isSpace)
import Text.Read (readMaybe)

-- | Query filters, not the full set of order states in a response.
data OrderStatus = OrdersOpen | OrdersClosed | OrdersAll
  deriving (Eq, Show)

data OrderDirection = Asc | Desc
  deriving (Eq, Show)

data OrdersCommand = OrdersCommand
  { ordersStatus :: OrderStatus
  , ordersLimit :: Maybe Int
  , ordersSymbols :: Maybe [String]
  , ordersDirection :: OrderDirection
  , ordersOutput :: Maybe FilePath
  }
  deriving (Eq, Show)

orderStatusParameter :: OrderStatus -> ByteString
orderStatusParameter OrdersOpen = "open"
orderStatusParameter OrdersClosed = "closed"
orderStatusParameter OrdersAll = "all"

orderDirectionParameter :: OrderDirection -> ByteString
orderDirectionParameter Asc = "asc"
orderDirectionParameter Desc = "desc"

parseOrderStatus :: String -> Either String OrderStatus
parseOrderStatus "open" = Right OrdersOpen
parseOrderStatus "closed" = Right OrdersClosed
parseOrderStatus "all" = Right OrdersAll
parseOrderStatus _ = Left "Expected open, closed, or all"

parseOrderDirection :: String -> Either String OrderDirection
parseOrderDirection "asc" = Right Asc
parseOrderDirection "desc" = Right Desc
parseOrderDirection _ = Left "Expected asc or desc"

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

strip :: String -> String
strip = dropWhile isSpace . reverse . dropWhile isSpace . reverse

splitCommas :: String -> [String]
splitCommas input =
  case break (== ',') input of
    (part, []) -> [part]
    (part, _ : rest) -> part : splitCommas rest

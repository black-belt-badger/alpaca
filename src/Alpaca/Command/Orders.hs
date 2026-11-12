{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Orders
  ( OrdersCommand (..)
  , OrderFilter (..)
  , OrderDirection (..)
  , orderFilterParameter
  , orderDirectionParameter
  , parseOrderFilter
  , parseOrderDirection
  , parseOrderLimit
  , parseOrderSymbol
  ) where

import Data.ByteString (ByteString)
import Data.Char (isAsciiLower, isAsciiUpper)
import Text.Read (readMaybe)

data OrderFilter = OpenOrders | ClosedOrders | AllOrders
  deriving (Eq, Show)

data OrderDirection = Ascending | Descending
  deriving (Eq, Show)

data OrdersCommand = OrdersCommand
  { ordersStatus :: OrderFilter
  , ordersLimit :: Maybe Int
  , ordersSymbols :: [String]
  , ordersDirection :: OrderDirection
  , ordersOutput :: Maybe FilePath
  }
  deriving (Eq, Show)

orderFilterParameter :: OrderFilter -> ByteString
orderFilterParameter OpenOrders = "open"
orderFilterParameter ClosedOrders = "closed"
orderFilterParameter AllOrders = "all"

orderDirectionParameter :: OrderDirection -> ByteString
orderDirectionParameter Ascending = "asc"
orderDirectionParameter Descending = "desc"

parseOrderFilter :: String -> Either String OrderFilter
parseOrderFilter "open" = Right OpenOrders
parseOrderFilter "closed" = Right ClosedOrders
parseOrderFilter "all" = Right AllOrders
parseOrderFilter _ = Left "Expected open, closed, or all"

parseOrderDirection :: String -> Either String OrderDirection
parseOrderDirection "asc" = Right Ascending
parseOrderDirection "desc" = Right Descending
parseOrderDirection _ = Left "Expected asc or desc"

parseOrderLimit :: String -> Either String Int
parseOrderLimit value =
  case readMaybe value of
    Just n | n >= 1 && n <= 500 -> Right n
    _ -> Left "Expected a whole number between 1 and 500"

-- | An individual symbol, not a comma-separated query string. The HTTP
-- client will encode the combined list, including crypto symbols with '/'.
parseOrderSymbol :: String -> Either String String
parseOrderSymbol value
  | not (null value) && all validChar value = Right value
  | otherwise = Left "Expected a nonempty symbol (letters, digits, /, ., _, -)"
  where
    validChar char =
      isAsciiUpper char || isAsciiLower char || (char >= '0' && char <= '9')
        || char `elem` ("/._-" :: String)

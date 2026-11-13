module Alpaca.Command.Order
  ( OrderId
  , parseOrderId
  , orderIdSegment
  , OrderCommand (..)
  , OrderGetCommand (..)
  , OrderCancelCommand (..)
  ) where

import Alpaca.Command.Order.Submit (SubmitCommand)

-- | An Alpaca server-assigned order ID. Its constructor is private so
-- request builders cannot accidentally interpolate an unsafe path segment.
newtype OrderId = OrderId String deriving (Eq, Show)

-- | Alpaca specifies a UUID. Validate the entire canonical form, including
-- separators, before making an authenticated request.
parseOrderId :: String -> Either String OrderId
parseOrderId value
  | length value == 36 && all validPosition (zip [0 :: Int ..] value) =
      Right (OrderId value)
  | otherwise =
      Left "Expected an order UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)"
  where
    validPosition (index, char)
      | index `elem` [8, 13, 18, 23] = char == '-'
      | otherwise = isAsciiHex char

    isAsciiHex char =
      (char >= '0' && char <= '9')
        || (char >= 'a' && char <= 'f')
        || (char >= 'A' && char <= 'F')

-- | Safe path component; only available after UUID validation.
orderIdSegment :: OrderId -> String
orderIdSegment (OrderId value) = value

data OrderGetCommand = OrderGetCommand
  { getOrderId :: OrderId
  , getOrderNested :: Bool
  , getOrderOutput :: Maybe FilePath
  }
  deriving (Eq, Show)

-- | No HTTP request is made unless the user explicitly passes --confirm.
data OrderCancelCommand = OrderCancelCommand
  { cancelOrderId :: OrderId
  , cancelConfirmed :: Bool
  }
  deriving (Eq, Show)

data OrderCommand
  = GetOrder OrderGetCommand
  | SubmitOrder SubmitCommand
  | CancelOrder OrderCancelCommand
  deriving (Eq, Show)

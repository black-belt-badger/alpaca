{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.Order
  ( Order (..)
  , decodeOrders
  ) where

import Data.Aeson (FromJSON (..), eitherDecodeStrict', withObject, (.:), (.:?))
import Data.ByteString (ByteString)
import Data.Text (Text)

-- | Fields suitable for a human-readable summary. Decimals and timestamps
-- remain exact strings; original JSON is retained by the caller for --out.
data Order = Order
  { orderId :: Text
  , orderClientId :: Maybe Text
  , orderSymbol :: Text
  , orderSide :: Text
  , orderType :: Text
  , orderStatus :: Text
  , orderQuantity :: Maybe Text
  , orderNotional :: Maybe Text
  , orderFilledQuantity :: Maybe Text
  , orderLimitPrice :: Maybe Text
  , orderStopPrice :: Maybe Text
  , orderSubmittedAt :: Maybe Text
  , orderFilledAt :: Maybe Text
  }
  deriving (Eq, Show)

instance FromJSON Order where
  parseJSON = withObject "Order" $ \o ->
    Order
      <$> o .: "id"
      <*> o .:? "client_order_id"
      <*> o .: "symbol"
      <*> o .: "side"
      <*> o .: "type"
      <*> o .: "status"
      <*> o .:? "qty"
      <*> o .:? "notional"
      <*> o .:? "filled_qty"
      <*> o .:? "limit_price"
      <*> o .:? "stop_price"
      <*> o .:? "submitted_at"
      <*> o .:? "filled_at"

-- | Alpaca returns a JSON array, including [] when no orders match.
decodeOrders :: ByteString -> Either String [Order]
decodeOrders = eitherDecodeStrict'

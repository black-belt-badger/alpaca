{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.Order
  ( Order (..)
  , decodeOrders
  , decodeOrder
  ) where

import Data.Aeson (FromJSON (..), eitherDecodeStrict', withObject, (.:), (.:?))
import Data.ByteString (ByteString)
import Data.Text (Text)

-- | Provider quantities and monetary values are JSON strings, never Double.
-- Optional financial and timestamp fields can be missing or null.
-- Keep the original response for --out rather than reconstructing JSON.
data Order = Order
  { orderId :: Text
  , orderClientOrderId :: Text
  , orderSymbol :: Text
  , orderAssetClass :: Maybe Text
  , orderSide :: Text
  , orderType :: Text
  , orderState :: Text
  , orderQty :: Maybe Text
  , orderNotional :: Maybe Text
  , orderFilledQty :: Text
  , orderFilledAvgPrice :: Maybe Text
  , orderLimitPrice :: Maybe Text
  , orderStopPrice :: Maybe Text
  , orderCreatedAt :: Text
  , orderSubmittedAt :: Maybe Text
  , orderFilledAt :: Maybe Text
  }
  deriving (Eq, Show)

instance FromJSON Order where
  parseJSON = withObject "Order" $ \o ->
    Order
      <$> o .: "id"
      <*> o .: "client_order_id"
      <*> o .: "symbol"
      <*> o .:? "asset_class"
      <*> o .: "side"
      <*> o .: "type"
      <*> o .: "status"
      <*> o .:? "qty"
      <*> o .:? "notional"
      <*> o .: "filled_qty"
      <*> o .:? "filled_avg_price"
      <*> o .:? "limit_price"
      <*> o .:? "stop_price"
      <*> o .: "created_at"
      <*> o .:? "submitted_at"
      <*> o .:? "filled_at"

-- | GET /v2/orders/{order_id} returns an object, not an array.
decodeOrder :: ByteString -> Either String Order
decodeOrder = eitherDecodeStrict'

decodeOrders :: ByteString -> Either String [Order]
decodeOrders = eitherDecodeStrict'

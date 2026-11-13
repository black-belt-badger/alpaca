{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.Order
  ( Order (..)
  , OrderDetails (..)
  , OrderSide (..)
  , orderSideValue
  , OrderState (..)
  , orderStateValue
  , OrderType (..)
  , orderTypeValue
  , OrderClass (..)
  , orderClassValue
  , OrderTimeInForce (..)
  , orderTimeInForceValue
  , OrderPositionIntent (..)
  , orderPositionIntentValue
  , decodeOrders
  , decodeOrder
  ) where

import Data.Aeson (FromJSON (..), ToJSON (..), Value (..), eitherDecodeStrict', withObject, withText, (.:), (.:?))
import Data.Aeson.Types (Parser)
import Data.Aeson.KeyMap (KeyMap)
import Data.ByteString (ByteString)
import Data.Text (Text)
import qualified Data.Text as Text

-- | Open Alpaca OrderSide vocabulary; unknown future values are retained.
data OrderSide
  = OrderBuy
  | OrderSell
  | SideOther Text
  deriving (Eq, Ord, Show)

orderSideValue :: OrderSide -> Text
orderSideValue value = case value of
  OrderBuy -> "buy"
  OrderSell -> "sell"
  SideOther other -> other

instance FromJSON OrderSide where
  parseJSON = withText "OrderSide" $ \value ->
    if Text.null value
      then fail "Empty OrderSide value"
      else pure $ case value of
      "buy" -> OrderBuy
      "sell" -> OrderSell
      other -> SideOther other

instance ToJSON OrderSide where
  toJSON = String . orderSideValue

-- | Open Alpaca OrderState vocabulary; unknown future values are retained.
data OrderState
  = StateNew
  | StatePartiallyFilled
  | StateFilled
  | StateDoneForDay
  | StateCanceled
  | StateExpired
  | StateReplaced
  | StatePendingCancel
  | StatePendingReplace
  | StateAccepted
  | StatePendingNew
  | StateAcceptedForBidding
  | StateStopped
  | StateRejected
  | StateSuspended
  | StateCalculated
  | StateHeld
  | StateOther Text
  deriving (Eq, Ord, Show)

orderStateValue :: OrderState -> Text
orderStateValue value = case value of
  StateNew -> "new"
  StatePartiallyFilled -> "partially_filled"
  StateFilled -> "filled"
  StateDoneForDay -> "done_for_day"
  StateCanceled -> "canceled"
  StateExpired -> "expired"
  StateReplaced -> "replaced"
  StatePendingCancel -> "pending_cancel"
  StatePendingReplace -> "pending_replace"
  StateAccepted -> "accepted"
  StatePendingNew -> "pending_new"
  StateAcceptedForBidding -> "accepted_for_bidding"
  StateStopped -> "stopped"
  StateRejected -> "rejected"
  StateSuspended -> "suspended"
  StateCalculated -> "calculated"
  StateHeld -> "held"
  StateOther other -> other

instance FromJSON OrderState where
  parseJSON = withText "OrderState" $ \value ->
    if Text.null value
      then fail "Empty OrderState value"
      else pure $ case value of
      "new" -> StateNew
      "partially_filled" -> StatePartiallyFilled
      "filled" -> StateFilled
      "done_for_day" -> StateDoneForDay
      "canceled" -> StateCanceled
      "expired" -> StateExpired
      "replaced" -> StateReplaced
      "pending_cancel" -> StatePendingCancel
      "pending_replace" -> StatePendingReplace
      "accepted" -> StateAccepted
      "pending_new" -> StatePendingNew
      "accepted_for_bidding" -> StateAcceptedForBidding
      "stopped" -> StateStopped
      "rejected" -> StateRejected
      "suspended" -> StateSuspended
      "calculated" -> StateCalculated
      "held" -> StateHeld
      other -> StateOther other

instance ToJSON OrderState where
  toJSON = String . orderStateValue

-- | Open Alpaca OrderType vocabulary; unknown future values are retained.
data OrderType
  = TypeMarket
  | TypeLimit
  | TypeStop
  | TypeStopLimit
  | TypeTrailingStop
  | OrderTypeOther Text
  deriving (Eq, Ord, Show)

orderTypeValue :: OrderType -> Text
orderTypeValue value = case value of
  TypeMarket -> "market"
  TypeLimit -> "limit"
  TypeStop -> "stop"
  TypeStopLimit -> "stop_limit"
  TypeTrailingStop -> "trailing_stop"
  OrderTypeOther other -> other

instance FromJSON OrderType where
  parseJSON = withText "OrderType" $ \value ->
    if Text.null value
      then fail "Empty OrderType value"
      else pure $ case value of
      "market" -> TypeMarket
      "limit" -> TypeLimit
      "stop" -> TypeStop
      "stop_limit" -> TypeStopLimit
      "trailing_stop" -> TypeTrailingStop
      other -> OrderTypeOther other

instance ToJSON OrderType where
  toJSON = String . orderTypeValue

-- | Open Alpaca OrderClass vocabulary; unknown future values are retained.
data OrderClass
  = ClassSimple
  | ClassBracket
  | ClassOto
  | ClassOco
  | ClassMleg
  | OrderClassOther Text
  deriving (Eq, Ord, Show)

orderClassValue :: OrderClass -> Text
orderClassValue value = case value of
  ClassSimple -> "simple"
  ClassBracket -> "bracket"
  ClassOto -> "oto"
  ClassOco -> "oco"
  ClassMleg -> "mleg"
  OrderClassOther other -> other

instance FromJSON OrderClass where
  parseJSON = withText "OrderClass" $ \value ->
    pure $ case value of
      "" -> ClassSimple
      "simple" -> ClassSimple
      "bracket" -> ClassBracket
      "oto" -> ClassOto
      "oco" -> ClassOco
      "mleg" -> ClassMleg
      other -> OrderClassOther other

instance ToJSON OrderClass where
  toJSON = String . orderClassValue

-- | Open Alpaca OrderTimeInForce vocabulary; unknown future values are retained.
data OrderTimeInForce
  = TifDay
  | TifGtc
  | TifOpg
  | TifCls
  | TifIoc
  | TifFok
  | TimeInForceOther Text
  deriving (Eq, Ord, Show)

orderTimeInForceValue :: OrderTimeInForce -> Text
orderTimeInForceValue value = case value of
  TifDay -> "day"
  TifGtc -> "gtc"
  TifOpg -> "opg"
  TifCls -> "cls"
  TifIoc -> "ioc"
  TifFok -> "fok"
  TimeInForceOther other -> other

instance FromJSON OrderTimeInForce where
  parseJSON = withText "OrderTimeInForce" $ \value ->
    if Text.null value
      then fail "Empty OrderTimeInForce value"
      else pure $ case value of
      "day" -> TifDay
      "gtc" -> TifGtc
      "opg" -> TifOpg
      "cls" -> TifCls
      "ioc" -> TifIoc
      "fok" -> TifFok
      other -> TimeInForceOther other

instance ToJSON OrderTimeInForce where
  toJSON = String . orderTimeInForceValue

-- | Open Alpaca OrderPositionIntent vocabulary; unknown future values are retained.
data OrderPositionIntent
  = IntentBuyToOpen
  | IntentBuyToClose
  | IntentSellToOpen
  | IntentSellToClose
  | IntentOther Text
  deriving (Eq, Ord, Show)

orderPositionIntentValue :: OrderPositionIntent -> Text
orderPositionIntentValue value = case value of
  IntentBuyToOpen -> "buy_to_open"
  IntentBuyToClose -> "buy_to_close"
  IntentSellToOpen -> "sell_to_open"
  IntentSellToClose -> "sell_to_close"
  IntentOther other -> other

instance FromJSON OrderPositionIntent where
  parseJSON = withText "OrderPositionIntent" $ \value ->
    if Text.null value
      then fail "Empty OrderPositionIntent value"
      else pure $ case value of
      "buy_to_open" -> IntentBuyToOpen
      "buy_to_close" -> IntentBuyToClose
      "sell_to_open" -> IntentSellToOpen
      "sell_to_close" -> IntentSellToClose
      other -> IntentOther other

instance ToJSON OrderPositionIntent where
  toJSON = String . orderPositionIntentValue

-- | Less frequently summarized, but documented order fields. All are
-- optional because leg, class, and endpoint response variants differ.
-- Monetary and quantity values are exact provider decimal strings;
-- malformed JSON numeric scalars are never silently rounded.
data OrderDetails = OrderDetails
  { orderAssetId :: Maybe Text
  , orderPositionIntent :: Maybe OrderPositionIntent
  , orderLegacyType :: Maybe Text
  , orderClass :: Maybe OrderClass
  , orderTimeInForce :: Maybe OrderTimeInForce
  , orderTrailPrice :: Maybe Text
  , orderTrailPercent :: Maybe Text
  , orderHwm :: Maybe Text
  , orderExtendedHours :: Maybe Bool
  , orderUpdatedAt :: Maybe Text
  , orderExpiredAt :: Maybe Text
  , orderCanceledAt :: Maybe Text
  , orderFailedAt :: Maybe Text
  , orderReplacedAt :: Maybe Text
  , orderReplacedBy :: Maybe Text
  , orderReplaces :: Maybe Text
  , orderExpiresAt :: Maybe Text
  , orderGroupId :: Maybe Text
  , orderGroupRole :: Maybe Text
  , orderSource :: Maybe Text
  , orderSubtag :: Maybe Text
  , orderRatioQty :: Maybe Text
  }
  deriving (Eq, Show)

instance FromJSON OrderDetails where
  parseJSON = withObject "OrderDetails" $ \o ->
    OrderDetails
      <$> o .:? "asset_id"
      <*> o .:? "position_intent"
      <*> o .:? "order_type"
      <*> o .:? "order_class"
      <*> o .:? "time_in_force"
      <*> o .:? "trail_price"
      <*> o .:? "trail_percent"
      <*> o .:? "hwm"
      <*> o .:? "extended_hours"
      <*> o .:? "updated_at"
      <*> o .:? "expired_at"
      <*> o .:? "canceled_at"
      <*> o .:? "failed_at"
      <*> o .:? "replaced_at"
      <*> o .:? "replaced_by"
      <*> o .:? "replaces"
      <*> o .:? "expires_at"
      <*> o .:? "group_id"
      <*> o .:? "group_role"
      <*> o .:? "source"
      <*> o .:? "subtag"
      <*> o .:? "ratio_qty"

-- | Complete typed Alpaca order, shared between GET /v2/orders and
-- GET /v2/orders/{id}. Legs are also Order values, but cannot nest again.
-- Keep the original raw response unchanged for --out exports; this value
-- intentionally does not reconstruct undocumented extension properties.
data Order = Order
  { orderId :: Text
  , orderClientOrderId :: Maybe Text
  , orderSymbol :: Maybe Text
  , orderAssetClass :: Maybe Text
  , orderSide :: Maybe OrderSide
  , orderType :: Maybe OrderType
  , orderState :: OrderState
  , orderQty :: Maybe Text
  , orderNotional :: Maybe Text
  , orderFilledQty :: Maybe Text
  , orderFilledAvgPrice :: Maybe Text
  , orderLimitPrice :: Maybe Text
  , orderStopPrice :: Maybe Text
  , orderCreatedAt :: Maybe Text
  , orderSubmittedAt :: Maybe Text
  , orderFilledAt :: Maybe Text
  , orderDetails :: OrderDetails
  , orderLegs :: Maybe [Order]
  }
  deriving (Eq, Show)

instance FromJSON Order where
  parseJSON = parseOrderAt 0

parseOrderAt :: Int -> Value -> Parser Order
parseOrderAt depth = withObject "Order" $ \o -> do
  legs <- parseLegs depth o
  Order
    <$> (o .: "id" >>= nonblankId)
    <*> o .:? "client_order_id"
    <*> o .:? "symbol"
    <*> o .:? "asset_class"
    <*> o .:? "side"
    <*> o .:? "type"
    <*> o .: "status"
    <*> o .:? "qty"
    <*> o .:? "notional"
    <*> o .:? "filled_qty"
    <*> o .:? "filled_avg_price"
    <*> o .:? "limit_price"
    <*> o .:? "stop_price"
    <*> o .:? "created_at"
    <*> o .:? "submitted_at"
    <*> o .:? "filled_at"
    <*> parseJSON (Object o)
    <*> pure legs

nonblankId :: Text -> Parser Text
nonblankId value
  | Text.null (Text.strip value) = fail "Missing nonblank order id"
  | otherwise = pure value

parseLegs :: Int -> KeyMap Value -> Parser (Maybe [Order])
parseLegs depth o = do
  maybeLegs <- o .:? "legs" :: Parser (Maybe [Value])
  case maybeLegs of
    Nothing -> pure Nothing
    Just values
      | depth >= 1 && not (null values) -> fail "Order legs may not nest"
      | otherwise -> Just <$> traverse (parseOrderAt (depth + 1)) values

-- | GET /v2/orders/{order_id} returns a single object, not an array.
decodeOrder :: ByteString -> Either String Order
decodeOrder = eitherDecodeStrict'

decodeOrders :: ByteString -> Either String [Order]
decodeOrders = eitherDecodeStrict'

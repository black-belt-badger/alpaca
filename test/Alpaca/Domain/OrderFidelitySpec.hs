{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.OrderFidelitySpec (spec) where

import Alpaca.Command.Orders.Run (renderOrderSummary)
import Alpaca.Domain.Order
  ( Order (..), OrderDetails (..), OrderSide (..), OrderState (..)
  , OrderType (..), OrderClass (..), OrderTimeInForce (..)
  , OrderPositionIntent (..), decodeOrder, decodeOrders
  , orderSideValue, orderStateValue, orderTypeValue
  )
import Data.Aeson (Result (..), Value (String), fromJSON, toJSON)
import qualified Data.ByteString as Bytes
import Data.ByteString (ByteString)
import Data.Either (isLeft)
import qualified Data.Text as Text
import Paths_kirke (getDataFileName)
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

spec :: Spec
spec = do
  it "decodes six synthetic orders from the same contract pack as Atalanta" $ do
    body <- fixture "orders-mixed.json"
    case decodeOrders body of
      Left failure -> fail failure
      Right [equity, crypto, multi, bracket, trailing, future] -> do
        orderState equity `shouldBe` StatePartiallyFilled
        orderState crypto `shouldBe` StateFilled
        orderSide multi `shouldBe` Nothing
        orderClass (orderDetails multi) `shouldBe` Just ClassMleg
        orderClass (orderDetails bracket) `shouldBe` Just ClassBracket
        orderType trailing `shouldBe` Just TypeTrailingStop
        orderState future `shouldBe` StateOther "FUTURE_STATUS"
      Right other -> fail ("Expected six orders, got " <> show (length other))

  it "decodes the full partially filled equity order with precise string values" $ do
    equity <- one "order-equity.json"
    orderId equity `shouldBe` "11111111-2222-4333-8444-555555555555"
    orderClientOrderId equity `shouldBe` Just "SYNTHETIC-EQUITY-ORDER-1"
    orderSymbol equity `shouldBe` Just "AAPL"
    orderState equity `shouldBe` StatePartiallyFilled
    orderSide equity `shouldBe` Just OrderBuy
    orderType equity `shouldBe` Just TypeLimit
    orderQty equity `shouldBe` Just "5.123456789012345678901"
    orderFilledQty equity `shouldBe` Just "2.000000000000000001"
    orderFilledAvgPrice equity `shouldBe` Just "192.00000000000000000001"
    orderLimitPrice equity `shouldBe` Just "193.1234567890123456789"
    orderCreatedAt equity `shouldBe` Just "2026-11-13T00:10:01.123456789Z"
    orderPositionIntent (orderDetails equity) `shouldBe` Just IntentBuyToOpen
    orderClass (orderDetails equity) `shouldBe` Just ClassSimple
    orderTimeInForce (orderDetails equity) `shouldBe` Just TifDay
    orderExtendedHours (orderDetails equity) `shouldBe` Just False
    orderUpdatedAt (orderDetails equity) `shouldBe`
      Just "2026-11-13T00:11:02.123456789Z"
    orderLegs equity `shouldBe` Nothing

  it "handles crypto notional orders, null quantity and explicit empty legs" $ do
    crypto <- one "order-crypto.json"
    orderAssetClass crypto `shouldBe` Just "crypto"
    orderQty crypto `shouldBe` Nothing
    orderNotional crypto `shouldBe` Just "25.1234567890123456789012345"
    orderFilledQty crypto `shouldBe` Just "0.000375291823456789012345"
    orderFilledAt crypto `shouldBe` Just "2026-11-13T01:01:02.000000123Z"
    orderLegs crypto `shouldBe` Just []

  it "decodes nested multi-leg options with null parent side and exact leg ratios" $ do
    parent <- one "order-mleg.json"
    orderSide parent `shouldBe` Nothing
    orderClass (orderDetails parent) `shouldBe` Just ClassMleg
    case orderLegs parent of
      Just [buyLeg, sellLeg] -> do
        orderSide buyLeg `shouldBe` Just OrderBuy
        orderSide sellLeg `shouldBe` Just OrderSell
        orderPositionIntent (orderDetails buyLeg) `shouldBe` Just IntentBuyToOpen
        orderPositionIntent (orderDetails sellLeg) `shouldBe` Just IntentSellToOpen
        orderRatioQty (orderDetails buyLeg) `shouldBe` Just "1.000000000000000001"
        orderRatioQty (orderDetails sellLeg) `shouldBe` Just "2.000000000000000002"
        orderLimitPrice buyLeg `shouldBe` Just "1.2500000001"
        orderLegs buyLeg `shouldBe` Nothing
      _ -> fail "Expected exactly two typed option legs"
    let summary = renderOrderSummary parent
    summary `shouldSatisfy` Text.isInfixOf "Legs: 2"
    summary `shouldSatisfy` Text.isInfixOf "ratio 1.000000000000000001"
    summary `shouldSatisfy` Text.isInfixOf "ratio 2.000000000000000002"

  it "decodes bracket entry and typed stop-loss child" $ do
    bracket <- one "order-bracket.json"
    orderClass (orderDetails bracket) `shouldBe` Just ClassBracket
    case orderLegs bracket of
      Just [stop] -> do
        orderType stop `shouldBe` Just TypeStop
        orderStopPrice stop `shouldBe` Just "400.50"
        orderFilledQty stop `shouldBe` Just "0"
      _ -> fail "Expected bracket stop leg"

  it "preserves trailing stop fields and high-water mark exactly" $ do
    trailing <- one "order-trailing.json"
    orderTrailPrice (orderDetails trailing) `shouldBe` Just "2.5"
    orderTrailPercent (orderDetails trailing) `shouldBe` Nothing
    orderHwm (orderDetails trailing) `shouldBe` Just "252.123456789"
    orderExtendedHours (orderDetails trailing) `shouldBe` Nothing

  it "keeps previously unknown response enum strings instead of rejecting orders" $ do
    future <- one "order-future.json"
    orderState future `shouldBe` StateOther "FUTURE_STATUS"
    orderSide future `shouldBe` Just (SideOther "FUTURE_SIDE")
    orderType future `shouldBe` Just (OrderTypeOther "FUTURE_TYPE")
    orderTimeInForce (orderDetails future) `shouldBe` Just (TimeInForceOther "FUTURE_TIF")
    orderQty future `shouldBe` Nothing

  it "round trips typed known and unknown order enums without normalization" $ do
    fromJSON (String "partially_filled") `shouldBe`
      Success StatePartiallyFilled
    fromJSON (String "future_status") `shouldBe`
      Success (StateOther "future_status")
    fromJSON (String "buy") `shouldBe` Success OrderBuy
    fromJSON (String "future_side") `shouldBe` Success (SideOther "future_side")
    toJSON (StateOther "future_status") `shouldBe` String "future_status"
    toJSON (SideOther "future_side") `shouldBe` String "future_side"
    orderStateValue StatePartiallyFilled `shouldBe` "partially_filled"
    orderSideValue OrderSell `shouldBe` "sell"
    orderTypeValue TypeLimit `shouldBe` "limit"

  it "distinguishes string zero from null and preserves explicit empty legs" $ do
    decodeOrder "{\"id\":\"a\",\"status\":\"new\",\"qty\":\"0\",\"legs\":null}"
      `shouldSatisfy` either (const False) (\o -> orderQty o == Just "0" && orderLegs o == Nothing)
    decodeOrder "{\"id\":\"a\",\"status\":\"new\",\"qty\":null,\"legs\":[]}"
      `shouldSatisfy` either (const False) (\o -> orderQty o == Nothing && orderLegs o == Just [])

  it "rejects malformed roots, legs and recursive nonempty grandchildren" $ do
    decodeOrders "[null]" `shouldSatisfy` isLeft
    decodeOrders "[42]" `shouldSatisfy` isLeft
    decodeOrders "{}" `shouldSatisfy` isLeft
    decodeOrder "[]" `shouldSatisfy` isLeft
    decodeOrder "{\"id\":\"a\",\"status\":\"new\",\"legs\":\"invalid\"}"
      `shouldSatisfy` isLeft
    decodeOrder "{\"id\":\"a\",\"status\":\"new\",\"legs\":[null]}"
      `shouldSatisfy` isLeft
    decodeOrder "{\"id\":\"a\",\"status\":\"new\",\"legs\":[{\"id\":\"b\",\"status\":\"new\",\"legs\":[{\"id\":\"c\",\"status\":\"new\"}]}]}"
      `shouldSatisfy` isLeft
    decodeOrder "{\"id\":\"a\",\"status\":\"new\",\"legs\":[{\"id\":\"b\",\"status\":\"new\",\"legs\":[]}]}"
      `shouldSatisfy` either (const False) (\o -> maybe False ((== 1) . length) (orderLegs o))

  it "rejects wrong scalar types for financial, boolean and enum fields" $ do
    decodeOrder "{\"id\":\"a\",\"status\":\"new\",\"ratio_qty\":0.00000001}"
      `shouldSatisfy` isLeft
    decodeOrder "{\"id\":\"a\",\"status\":\"new\",\"trail_price\":123.45}"
      `shouldSatisfy` isLeft
    decodeOrder "{\"id\":\"a\",\"status\":\"new\",\"extended_hours\":\"true\"}"
      `shouldSatisfy` isLeft
    decodeOrder "{\"id\":\"a\",\"status\":\"new\",\"order_class\":42}"
      `shouldSatisfy` isLeft
    decodeOrder "{\"id\":\"a\",\"status\":\"new\",\"qty\":false}"
      `shouldSatisfy` isLeft

  it "leaves original raw fixture bytes intact for private JSON export" $ do
    body <- fixture "order-equity.json"
    decodeOrder body `shouldSatisfy` either (const False) (const True)
    body `shouldSatisfy` (Bytes.isInfixOf "\"provider_future_decimal\"")
    body `shouldSatisfy` (Bytes.isInfixOf "0.123456789012345678901234567890123456789")
    -- Order summaries are typed projections; runOrders saves original body
    -- via savePrivateJson, never by round-tripping a parsed Order.

  it "rejects empty provider identity, state, side and type" $ do
    decodeOrder "{\"id\":\"\",\"status\":\"new\"}" `shouldSatisfy` isLeft
    decodeOrder "{\"id\":\"   \",\"status\":\"new\"}" `shouldSatisfy` isLeft
    decodeOrder "{\"id\":\"a\",\"status\":\"\"}" `shouldSatisfy` isLeft
    decodeOrder "{\"id\":\"a\",\"status\":\"new\",\"side\":\"\"}"
      `shouldSatisfy` isLeft
    decodeOrder "{\"id\":\"a\",\"status\":\"new\",\"type\":\"\"}"
      `shouldSatisfy` isLeft

  it "accepts empty simple order_class for provider compatibility" $ do
    case decodeOrder "{\"id\":\"a\",\"status\":\"new\",\"order_class\":\"\"}" of
      Right value -> orderClass (orderDetails value) `shouldBe` Just ClassSimple
      Left failure -> fail failure

  it "accepts empty orders" $
    decodeOrders "[]" `shouldBe` Right []

fixture :: String -> IO ByteString
fixture name = do
  file <- getDataFileName ("test/fixtures/orders/" <> name)
  Bytes.readFile file

one :: String -> IO Order
one name = do
  raw <- fixture name
  case decodeOrder raw of
    Left failure -> fail failure
    Right order -> pure order

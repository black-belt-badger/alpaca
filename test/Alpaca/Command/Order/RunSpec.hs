{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Order.RunSpec (spec) where

import Alpaca.Client (AlpacaError (..))
import Alpaca.Command.Order (OrderId, parseOrderId)
import Alpaca.Command.Order.Run (decodeOrderLookup, orderErrorMessage)
import Alpaca.Domain.Order (Order (..), OrderDetails (..), OrderSide (..), OrderState (..))
import qualified Data.ByteString as Bytes
import qualified Data.Text as Text
import Paths_kirke (getDataFileName)
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

equityId :: OrderId
equityId = either error id (parseOrderId "11111111-2222-4333-8444-555555555555")

cryptoId :: OrderId
cryptoId = either error id (parseOrderId "22222222-3333-4444-8555-666666666666")

multiId :: OrderId
multiId = either error id (parseOrderId "55555555-6666-4777-8888-999999999999")

spec :: Spec
spec = do
  it "distinguishes an unknown order from other HTTP errors" $
    orderErrorMessage (UnexpectedStatus 404)
      `shouldBe` "Alpaca paper order not found (HTTP 404)."

  it "preserves the explicit authentication error for HTTP 401" $
    orderErrorMessage (UnexpectedStatus 401)
      `shouldBe` "Alpaca paper API rejected the credentials (HTTP 401)."

  it "reports HTTP 403 and 503 without including provider response bodies" $ do
    orderErrorMessage (UnexpectedStatus 403)
      `shouldBe` "Alpaca paper API returned HTTP 403."
    orderErrorMessage (UnexpectedStatus 503)
      `shouldBe` "Alpaca paper API returned HTTP 503."

  it "does not echo the request or credentials on connection failure" $
    orderErrorMessage ConnectionFailed
      `shouldSatisfy` (not . ("example-secret" `elem`) . words)

  it "accepts a complete partial-fill order and passes original response bytes through unchanged" $ do
    raw <- fixture "order-equity.json"
    case decodeOrderLookup equityId (Right raw) of
      Left failure -> fail failure
      Right (order, saved) -> do
        orderId order `shouldBe` "11111111-2222-4333-8444-555555555555"
        orderState order `shouldBe` StatePartiallyFilled
        orderQty order `shouldBe` Just "5.123456789012345678901"
        orderFilledQty order `shouldBe` Just "2.000000000000000001"
        saved `shouldBe` raw
        saved `shouldSatisfy` Bytes.isInfixOf "provider_future_decimal"
        saved `shouldSatisfy`
          Bytes.isInfixOf "0.123456789012345678901234567890123456789"

  it "decodes notional crypto orders and exact decimal fills" $ do
    raw <- fixture "order-crypto.json"
    case decodeOrderLookup cryptoId (Right raw) of
      Left failure -> fail failure
      Right (order, _) -> do
        orderQty order `shouldBe` Nothing
        orderNotional order `shouldBe` Just "25.1234567890123456789012345"
        orderFilledQty order `shouldBe` Just "0.000375291823456789012345"

  it "handles a typed option parent with no side and exact nested leg ratios" $ do
    raw <- fixture "order-mleg.json"
    case decodeOrderLookup multiId (Right raw) of
      Left failure -> fail failure
      Right (parent, _) -> do
        orderSide parent `shouldBe` Nothing
        case orderLegs parent of
          Just [buyLeg, sellLeg] -> do
            orderSide buyLeg `shouldBe` Just OrderBuy
            orderSide sellLeg `shouldBe` Just OrderSell
            orderRatioQty (orderDetails buyLeg) `shouldBe` Just "1.000000000000000001"
            orderRatioQty (orderDetails sellLeg) `shouldBe` Just "2.000000000000000002"
          _ -> fail "Expected two option legs"

  it "compares UUIDs case-insensitively without changing response data" $ do
    let uppercase = either error id (parseOrderId "ABCDEF12-2222-4333-8444-555555555555")
        raw = "{\"id\":\"abcdef12-2222-4333-8444-555555555555\",\"status\":\"new\"}"
    case decodeOrderLookup uppercase (Right raw) of
      Left failure -> fail failure
      Right (order, bytes) -> do
        orderId order `shouldBe` "abcdef12-2222-4333-8444-555555555555"
        bytes `shouldBe` raw

  it "rejects a successful response for a different order without leaking either ID" $ do
    raw <- fixture "order-crypto.json"
    case decodeOrderLookup equityId (Right raw) of
      Left failure -> do
        failure `shouldBe` "Invalid Alpaca order response: order ID does not match requested UUID."
        failure `shouldSatisfy` (not . Text.isInfixOf "22222222" . Text.pack)
        failure `shouldSatisfy` (not . Text.isInfixOf "11111111" . Text.pack)
      Right _ -> fail "A mismatched provider order must not pass validation"

  it "treats malformed JSON, arrays, scalars and missing order identity as invalid" $ do
    forInvalid "{\"id\":\"SECRET_ID\",\"status\":true}"
    forInvalid "[]"
    forInvalid "\"PRIVATE_ORDER_RESPONSE\""
    forInvalid "42"
    forInvalid "{}"
    forInvalid "{\"status\":\"new\",\"qty\":\"2\"}"
    forInvalid "{\"id\":\"\",\"status\":\"new\"}"
    forInvalid "{\"id\":\"11111111-2222-4333-8444-555555555555\",\"status\":\"new\",\"legs\":[null]}"

  it "separates 404 absence from authentication, permissions, rate limits and server failures" $ do
    decodeOrderLookup equityId (Left (UnexpectedStatus 404))
      `shouldBe` Left "Alpaca paper order not found (HTTP 404)."
    decodeOrderLookup equityId (Left (UnexpectedStatus 401))
      `shouldBe` Left "Alpaca paper API rejected the credentials (HTTP 401)."
    decodeOrderLookup equityId (Left (UnexpectedStatus 403))
      `shouldBe` Left "Alpaca paper API returned HTTP 403."
    decodeOrderLookup equityId (Left (UnexpectedStatus 429))
      `shouldBe` Left "Alpaca paper API returned HTTP 429."
    decodeOrderLookup equityId (Left (UnexpectedStatus 503))
      `shouldBe` Left "Alpaca paper API returned HTTP 503."
    decodeOrderLookup equityId (Left ConnectionFailed)
      `shouldBe` Left "Could not connect to Alpaca's paper API. Check your network connection."

fixture :: String -> IO Bytes.ByteString
fixture name = do
  path <- getDataFileName ("test/fixtures/orders/" <> name)
  Bytes.readFile path

forInvalid :: Bytes.ByteString -> IO ()
forInvalid raw =
  case decodeOrderLookup equityId (Right raw) of
    Left failure -> do
      failure `shouldBe` "Invalid Alpaca order response (expected one valid order object)."
      failure `shouldSatisfy` (not . Text.isInfixOf "SECRET" . Text.pack)
      failure `shouldSatisfy` (not . Text.isInfixOf "PRIVATE" . Text.pack)
    Right _ -> fail "Malformed provider response unexpectedly accepted"

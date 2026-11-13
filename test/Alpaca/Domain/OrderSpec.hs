{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.OrderSpec (spec) where

import Alpaca.Domain.Order
  ( Order (..), OrderSide (..), OrderState (..), OrderType (..)
  , decodeOrder, decodeOrders)
import Data.ByteString (ByteString)
import qualified Data.ByteString as Bytes
import Data.Either (isLeft)
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

spec :: Spec
spec = do
  it "decodes crypto and equity orders with exact decimal strings" $ do
    let decoded = decodeOrders sample
    fmap length decoded `shouldBe` Right 2
    fmap (map orderSymbol) decoded `shouldBe` Right [Just "BTCUSD", Just "AAPL"]
    fmap (map orderSide) decoded `shouldBe` Right [Just OrderBuy, Just OrderSell]
    fmap (map orderType) decoded `shouldBe` Right [Just TypeMarket, Just TypeLimit]
    fmap (map orderQty) decoded `shouldBe` Right [Just "0.000000000123456789", Nothing]
    fmap (map orderNotional) decoded `shouldBe` Right [Nothing, Just "123.45000000"]
    fmap (map orderFilledAvgPrice) decoded `shouldBe` Right [Just "90000.123456789", Nothing]
    fmap (map orderState) decoded `shouldBe` Right [StateFilled, StateNew]

  it "decodes an individual order with missing/null optional fields" $ do
    let response = "{\"id\":\"id\",\"client_order_id\":\"client\",\"symbol\":\"SOLUSD\",\"side\":\"buy\",\"type\":\"market\",\"status\":\"new\",\"filled_qty\":\"0.00000000000001\",\"created_at\":\"2026-11-13T00:00:00Z\",\"qty\":null,\"submitted_at\":null,\"legs\":[]}"
    fmap orderSymbol (decodeOrder response) `shouldBe` Right (Just "SOLUSD")
    fmap orderFilledQty (decodeOrder response) `shouldBe` Right (Just "0.00000000000001")
    fmap orderQty (decodeOrder response) `shouldBe` Right Nothing
    fmap orderFilledAt (decodeOrder response) `shouldBe` Right Nothing
    fmap orderAssetClass (decodeOrder response) `shouldBe` Right Nothing

  it "rejects empty, array, wrong-shape, and malformed single order payloads" $ do
    decodeOrder "" `shouldSatisfy` isLeft
    decodeOrder "[]" `shouldSatisfy` isLeft
    decodeOrder "{}" `shouldSatisfy` isLeft
    decodeOrder "null" `shouldSatisfy` isLeft
    decodeOrder "{invalid" `shouldSatisfy` isLeft

  it "rejects numeric financial fields in single-order responses" $
    decodeOrder "{\"id\":\"id\",\"client_order_id\":\"client\",\"symbol\":\"SOLUSD\",\"side\":\"buy\",\"type\":\"market\",\"status\":\"new\",\"filled_qty\":0.01,\"created_at\":\"2026-11-13T00:00:00Z\"}"
      `shouldSatisfy` isLeft

  it "accepts an empty order list" $
    decodeOrders "[]" `shouldBe` Right []

  it "accepts absent or null optional order metadata" $ do
    let response = "[{\"id\":\"id\",\"client_order_id\":\"client\",\"symbol\":\"SOLUSD\",\"side\":\"buy\",\"type\":\"market\",\"status\":\"new\",\"filled_qty\":\"0\",\"created_at\":\"2026-11-13T00:00:00Z\",\"qty\":null,\"submitted_at\":null}]"
    fmap (map orderAssetClass) (decodeOrders response) `shouldBe` Right [Nothing]
    fmap (map orderQty) (decodeOrders response) `shouldBe` Right [Nothing]
    fmap (map orderSubmittedAt) (decodeOrders response) `shouldBe` Right [Nothing]
    fmap (map orderFilledAt) (decodeOrders response) `shouldBe` Right [Nothing]

  it "rejects wrong top-level shape and malformed JSON" $ do
    decodeOrders "{\"id\":\"x\"}" `shouldSatisfy` isLeft
    decodeOrders "[broken" `shouldSatisfy` isLeft

  it "rejects absent required identifiers and states" $ do
    decodeOrders "[{\"symbol\":\"BTCUSD\"}]" `shouldSatisfy` isLeft
    decodeOrders "[{\"id\":\"x\",\"client_order_id\":\"y\",\"symbol\":\"BTCUSD\"}]" `shouldSatisfy` isLeft

  it "rejects numeric quantities instead of rounding them" $
    decodeOrders (replace "\"qty\":\"0.000000000123456789\"" "\"qty\":0.000000000123456789" sample)
      `shouldSatisfy` isLeft

sample :: ByteString
sample =
  "["
    <> "{\"id\":\"uuid-crypto\",\"client_order_id\":\"cid-crypto\",\"symbol\":\"BTCUSD\","
    <> "\"asset_class\":\"crypto\",\"side\":\"buy\",\"type\":\"market\",\"status\":\"filled\","
    <> "\"qty\":\"0.000000000123456789\",\"notional\":null,\"filled_qty\":\"0.000000000123456789\","
    <> "\"filled_avg_price\":\"90000.123456789\",\"limit_price\":null,\"stop_price\":null,"
    <> "\"created_at\":\"2026-11-12T22:00:00Z\",\"submitted_at\":\"2026-11-12T22:00:00Z\","
    <> "\"filled_at\":\"2026-11-12T22:00:01Z\",\"provider_future_field\":{\"ignored\":true}},"
    <> "{\"id\":\"uuid-equity\",\"client_order_id\":\"cid-equity\",\"symbol\":\"AAPL\","
    <> "\"asset_class\":\"us_equity\",\"side\":\"sell\",\"type\":\"limit\",\"status\":\"new\","
    <> "\"qty\":null,\"notional\":\"123.45000000\",\"filled_qty\":\"0\","
    <> "\"filled_avg_price\":null,\"limit_price\":\"203.50\",\"created_at\":\"2026-11-12T23:00:00Z\"}"
    <> "]"

replace :: ByteString -> ByteString -> ByteString -> ByteString
replace old new body =
  let (before, rest) = Bytes.breakSubstring old body
   in if Bytes.null rest
        then body
        else before <> new <> Bytes.drop (Bytes.length old) rest

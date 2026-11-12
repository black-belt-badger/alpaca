{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.OrderSpec (spec) where

import Alpaca.Domain.Order (Order (..), decodeOrders)
import Data.ByteString (ByteString)
import Data.Either (isLeft)
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

spec :: Spec
spec = do
  it "decodes representative crypto and equity orders without decimal rounding" $
    shouldBe (decodeOrders sample)
      (Right
        [ Order "crypto-id" (Just "my-crypto")
            "BTCUSD" "buy" "market" "filled"
            (Just "0.000123456789") Nothing (Just "0.000123456789")
            Nothing Nothing (Just "2026-11-12T01:00:00Z") (Just "2026-11-12T01:00:01Z")
        , Order "equity-id" Nothing
            "AAPL" "sell" "limit" "new"
            (Just "2") Nothing (Just "0")
            (Just "200.50") Nothing Nothing Nothing
        ])

  it "accepts empty order lists" $
    shouldBe (decodeOrders "[]") (Right [])

  it "accepts null quantity for a notional order" $
    shouldBe (decodeOrders
      "[{\"id\":\"n\",\"symbol\":\"ETHUSD\",\"side\":\"buy\",\"type\":\"market\",\"status\":\"accepted\",\"qty\":null,\"notional\":\"10.25\"}]")
      (Right [Order "n" Nothing "ETHUSD" "buy" "market" "accepted"
        Nothing (Just "10.25") Nothing Nothing Nothing Nothing Nothing])

  it "rejects malformed or non-array responses" $ do
    shouldSatisfy (decodeOrders "bad") isLeft
    shouldSatisfy (decodeOrders "{\"id\":\"abc\"}") isLeft

  it "rejects missing essential fields and incorrect amount types" $ do
    shouldSatisfy (decodeOrders "[{\"id\":\"a\",\"symbol\":\"AAPL\"}]") isLeft
    shouldSatisfy (decodeOrders "[{\"id\":\"a\",\"symbol\":\"AAPL\",\"side\":\"buy\",\"type\":\"limit\",\"status\":\"new\",\"qty\":12}]") isLeft

sample :: ByteString
sample =
  mconcat
    [ "["
    , "{\"id\":\"crypto-id\",\"client_order_id\":\"my-crypto\",\"symbol\":\"BTCUSD\","
    , "\"side\":\"buy\",\"type\":\"market\",\"status\":\"filled\","
    , "\"qty\":\"0.000123456789\",\"filled_qty\":\"0.000123456789\","
    , "\"submitted_at\":\"2026-11-12T01:00:00Z\",\"filled_at\":\"2026-11-12T01:00:01Z\","
    , "\"extra_provider_field\":123},"
    , "{\"id\":\"equity-id\",\"symbol\":\"AAPL\",\"side\":\"sell\",\"type\":\"limit\","
    , "\"status\":\"new\",\"qty\":\"2\",\"filled_qty\":\"0\","
    , "\"limit_price\":\"200.50\",\"client_order_id\":null}"
    , "]"
    ]

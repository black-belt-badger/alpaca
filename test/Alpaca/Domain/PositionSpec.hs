{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.PositionSpec (spec) where

import Alpaca.Domain.Position (Position (..), decodePositions)
import Data.ByteString (ByteString)
import Data.Either (isLeft)
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

spec :: Spec
spec = do
  it "decodes crypto and equity positions with full decimal precision" $
    decodePositions exampleResponse
      `shouldBe`
        Right
          [ Position "BTCUSD" "crypto" "long" "0.000997498123456789" (Just "67.123456789012345") (Just "67291.12") (Just "-0.000000000001")
          , Position "AAPL" "us_equity" "short" "2" (Just "-400.50") (Just "200.25") (Just "50.50")
          ]

  it "accepts a portfolio with no open positions" $
    decodePositions "[]" `shouldBe` Right []

  it "tolerates null and absent optional monetary values" $
    decodePositions "[{\"symbol\":\"SOLUSD\",\"asset_class\":\"crypto\",\"side\":\"long\",\"qty\":\"0.125\",\"market_value\":null}]"
      `shouldBe`
        Right [Position "SOLUSD" "crypto" "long" "0.125" Nothing Nothing Nothing]

  it "rejects invalid JSON" $
    decodePositions "[oops" `shouldSatisfy` isLeft

  it "rejects a single object instead of a list" $
    decodePositions "{\"symbol\":\"BTCUSD\"}" `shouldSatisfy` isLeft

  it "rejects a missing required symbol" $
    decodePositions "[{\"qty\":\"1\",\"side\":\"long\",\"asset_class\":\"crypto\"}]"
      `shouldSatisfy` isLeft

  it "rejects a numeric quantity instead of a precise decimal string" $
    decodePositions "[{\"symbol\":\"BTCUSD\",\"qty\":0.125,\"side\":\"long\",\"asset_class\":\"crypto\"}]"
      `shouldSatisfy` isLeft

  it "rejects a numeric market value rather than rounding it" $
    decodePositions "[{\"symbol\":\"BTCUSD\",\"qty\":\"0.125\",\"side\":\"long\",\"asset_class\":\"crypto\",\"market_value\":10.50}]"
      `shouldSatisfy` isLeft

exampleResponse :: ByteString
exampleResponse =
  mconcat
    [ "["
    , "{\"symbol\":\"BTCUSD\",\"asset_class\":\"crypto\",\"side\":\"long\","
    , "\"qty\":\"0.000997498123456789\",\"market_value\":\"67.123456789012345\","
    , "\"current_price\":\"67291.12\",\"unrealized_pl\":\"-0.000000000001\","
    , "\"provider_future_field\":{\"ignored\":true}},"
    , "{\"symbol\":\"AAPL\",\"asset_class\":\"us_equity\",\"side\":\"short\","
    , "\"qty\":\"2\",\"market_value\":\"-400.50\","
    , "\"current_price\":\"200.25\",\"unrealized_pl\":\"50.50\"}"
    , "]"
    ]

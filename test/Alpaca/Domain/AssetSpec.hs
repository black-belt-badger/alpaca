{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.AssetSpec (spec) where

import Alpaca.Domain.Asset (Asset (..), decodeAssets)
import Data.ByteString (ByteString)
import Data.Either (isLeft)
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

spec :: Spec
spec = do
  it "decodes crypto and equity assets with strict required fields" $
    decodeAssets sample
      `shouldBe`
        Right
          [ Asset "crypto-uuid" "BTC/USD" (Just "Bitcoin") "crypto" "active" True (Just True)
          , Asset "equity-uuid" "AAPL" (Just "Apple Inc.") "us_equity" "inactive" False (Just False)
          ]

  it "accepts no matching assets" $
    decodeAssets "[]" `shouldBe` Right []

  it "accepts optional name and fractionable omitted or null" $
    decodeAssets "[{\"id\":\"uuid\",\"symbol\":\"SOL/USD\",\"class\":\"crypto\",\"status\":\"active\",\"tradable\":true,\"fractionable\":null}]"
      `shouldBe`
        Right [Asset "uuid" "SOL/USD" Nothing "crypto" "active" True Nothing]

  it "rejects a single object when an array is expected" $
    decodeAssets "{\"symbol\":\"BTC/USD\"}" `shouldSatisfy` isLeft

  it "rejects malformed JSON" $
    decodeAssets "[bad]" `shouldSatisfy` isLeft

  it "rejects absent required fields" $
    decodeAssets "[{\"symbol\":\"BTC/USD\"}]" `shouldSatisfy` isLeft

  it "rejects non-boolean tradability" $
    decodeAssets "[{\"id\":\"id\",\"symbol\":\"BTC/USD\",\"class\":\"crypto\",\"status\":\"active\",\"tradable\":\"yes\"}]"
      `shouldSatisfy` isLeft

  it "does not confuse asset class with the query parameter name" $
    decodeAssets "[{\"id\":\"id\",\"symbol\":\"BTC/USD\",\"asset_class\":\"crypto\",\"status\":\"active\",\"tradable\":true}]"
      `shouldSatisfy` isLeft

sample :: ByteString
sample =
  mconcat
    [ "["
    , "{\"id\":\"crypto-uuid\",\"symbol\":\"BTC/USD\",\"name\":\"Bitcoin\","
    , "\"class\":\"crypto\",\"status\":\"active\",\"tradable\":true,"
    , "\"fractionable\":true,\"extra\":{\"will\":\"be ignored\"}},"
    , "{\"id\":\"equity-uuid\",\"symbol\":\"AAPL\",\"name\":\"Apple Inc.\","
    , "\"class\":\"us_equity\",\"status\":\"inactive\",\"tradable\":false,"
    , "\"fractionable\":false}"
    , "]"
    ]

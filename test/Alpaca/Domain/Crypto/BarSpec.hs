{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.Crypto.BarSpec (spec) where

import Alpaca.Domain.Crypto.Bar
  ( CryptoBar (..)
  , CryptoBarsPage (..)
  , barCount
  , decodeCryptoBarsPage
  , encodeBarsJsonl
  , encodePagesJson
  , flattenBars
  )
import Data.Aeson (Value, eitherDecodeStrict')
import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as Char8
import qualified Data.Map.Strict as Map
import Data.Scientific (FPFormat (Fixed), formatScientific)
import Data.Either (isLeft)
import Data.Maybe (listToMaybe)
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

fixture :: ByteString
fixture =
  "{\"bars\":{\"BTC/USD\":[{\"t\":\"2026-10-02T00:00:00.123456789Z\","
    <> "\"o\":29000.123456789012345678,\"h\":29100,\"l\":28900.11,"
    <> "\"c\":29003.120000100,\"v\":0.000000000000123456789,\"n\":4,"
    <> "\"vw\":29001.123456789123456789,\"future_bar_data\":true}],"
    <> "\"ETH/USD\":[{\"t\":\"2026-10-02T00:00:00Z\","
    <> "\"o\":2200,\"h\":2205,\"l\":2199,\"c\":2201,\"v\":3.5,"
    <> "\"n\":null,\"vw\":null}]},"
    <> "\"next_page_token\":\"token-1\",\"future_page_metadata\":42}"

spec :: Spec
spec = do
  it "decodes multi-symbol crypto bars and preserves exact decimal values" $ do
    let page = either error id (decodeCryptoBarsPage fixture)
    Map.size (pageBars page) `shouldBe` 2
    barCount [page] `shouldBe` 2
    pageNextToken page `shouldBe` Just "token-1"
    let btc = maybe (error "Expected one BTC bar") id (listToMaybe (pageBars page Map.! "BTC/USD"))
    barTimestamp btc `shouldBe` "2026-10-02T00:00:00.123456789Z"
    formatScientific Fixed Nothing (barOpen btc)
      `shouldBe` "29000.123456789012345678"
    formatScientific Fixed Nothing (barVolume btc)
      `shouldBe` "0.000000000000123456789"
    formatScientific Fixed Nothing (barClose btc)
      `shouldBe` "29003.1200001"
    barTradeCount btc `shouldBe` Just 4
    fmap (formatScientific Fixed Nothing) (barVwap btc)
      `shouldBe` Just "29001.123456789123456789"

  it "handles absent optional n/vw, and null optional values" $ do
    let page = either error id (decodeCryptoBarsPage fixture)
    let eth = maybe (error "Expected one ETH bar") id (listToMaybe (pageBars page Map.! "ETH/USD"))
    barTradeCount eth `shouldBe` Nothing
    barVwap eth `shouldBe` Nothing
    let noExtras = "{\"bars\":{\"SOL/USD\":[{\"t\":\"2026-10-01T00:00:00Z\",\"o\":1,\"h\":1,\"l\":1,\"c\":1,\"v\":0}]},\"next_page_token\":null}"
    let sparse = either error id (decodeCryptoBarsPage noExtras)
    let sol = maybe (error "Expected one SOL bar") id (listToMaybe (pageBars sparse Map.! "SOL/USD"))
    barTradeCount sol `shouldBe` Nothing
    barVwap sol `shouldBe` Nothing
    pageNextToken sparse `shouldBe` Nothing

  it "handles no matching bars with absent or null page token" $ do
    let absent = either error id (decodeCryptoBarsPage "{\"bars\":{}}")
    let explicit = either error id (decodeCryptoBarsPage "{\"bars\":{},\"next_page_token\":null}")
    barCount [absent] `shouldBe` 0
    flattenBars [explicit] `shouldBe` []
    pageNextToken absent `shouldBe` Nothing
    pageNextToken explicit `shouldBe` Nothing

  it "rejects malformed pages, missing fields, and numeric types" $ do
    mapM_ (\input -> decodeCryptoBarsPage input `shouldSatisfy` isLeft)
      [ "", "[]", "{}", "{broken"
      , "{\"bars\":null}"
      , "{\"bars\":[1,2,3]}"
      , "{\"bars\":{\"BTC/USD\":[{\"o\":1}]}}"
      , "{\"bars\":{\"BTC/USD\":[{\"t\":\"2026-10-01T00:00:00Z\",\"o\":\"one\",\"h\":1,\"l\":1,\"c\":1,\"v\":2}]}}"
      ]

  it "JSON export keeps every original page, including unknown metadata" $ do
    let page = either error id (decodeCryptoBarsPage fixture)
        output = encodePagesJson [page, page]
    case (eitherDecodeStrict' output :: Either String Value) of
      Right result ->
        -- Parsing it back must retain exactly the provider JSON values.
        result `shouldBe` either (error . show) id
          (eitherDecodeStrict'
            ("{\"pages\":[" <> fixture <> "," <> fixture <>
             "],\"next_page_token\":\"token-1\"}"))
      Left err -> error err

  it "JSONL export has one record per bar, exact decimals and full timestamp" $ do
    let page = either error id (decodeCryptoBarsPage fixture)
        output = encodeBarsJsonl [page]
        records = Char8.lines output
    length records `shouldBe` 2
    output `shouldSatisfy` Char8.isInfixOf "\"symbol\":\"BTC/USD\""
    output `shouldSatisfy` Char8.isInfixOf "29000.123456789012345678"
    output `shouldSatisfy` Char8.isInfixOf "2026-10-02T00:00:00.123456789Z"
    mapM_ (\record ->
      (eitherDecodeStrict' record :: Either String Value) `shouldSatisfy` (not . isLeft))
      records

  it "can serialize no bars as empty JSONL" $ do
    let page = either error id (decodeCryptoBarsPage "{\"bars\":{}}")
    encodeBarsJsonl [page] `shouldBe` ""

{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.Crypto.TradeSpec (spec) where

import Alpaca.Domain.Crypto.Trade
  ( CryptoTrade (..)
  , CryptoTradesPage (..)
  , decodeCryptoTradesPage
  , forEachTrade
  , tradeCount
  , tradeToJson
  )
import Data.Aeson (Value, eitherDecodeStrict')
import qualified Data.Aeson as Aeson
import qualified Data.ByteString.Lazy as Lazy
import Data.ByteString (ByteString)
import Data.Either (isLeft)
import Data.IORef (modifyIORef', newIORef, readIORef)
import qualified Data.Map.Strict as Map
import Data.Scientific (FPFormat (Fixed), formatScientific)
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

fixture :: ByteString
fixture =
  "{\"trades\":{\"BTC/USD\":[{\"i\":123456789012345678901234567890,"
    <> "\"p\":29000.123456789012345678,\"s\":0.000000000000123456789,"
    <> "\"t\":\"2026-10-02T00:00:00.123456789Z\",\"tks\":\"S\","
    <> "\"future_trade_field\":true}],"
    <> "\"ETH/USD\":[{\"i\":31455287,\"p\":2200.5,\"s\":3,"
    <> "\"t\":\"2026-10-02T00:00:00Z\",\"tks\":null}]},"
    <> "\"next_page_token\":\"resume-token\",\"future_metadata\":42}"

decodeFixture :: ByteString -> CryptoTradesPage
decodeFixture = either error id . decodeCryptoTradesPage

spec :: Spec
spec = do
  it "decodes multiple symbols, arbitrary-size trade ID, exact decimals, and nanoseconds" $ do
    let page = decodeFixture fixture
        btc = headOrError (pageTrades page Map.! "BTC/USD")
    tradeCount page `shouldBe` 2
    Map.size (pageTrades page) `shouldBe` 2
    tradeId btc `shouldBe` 123456789012345678901234567890
    formatScientific Fixed Nothing (tradePrice btc)
      `shouldBe` "29000.123456789012345678"
    formatScientific Fixed Nothing (tradeSize btc)
      `shouldBe` "0.000000000000123456789"
    tradeTimestamp btc `shouldBe` "2026-10-02T00:00:00.123456789Z"
    tradeTakerSide btc `shouldBe` Just "S"
    pageNextToken page `shouldBe` Just "resume-token"

  it "accepts null or missing taker side, including future side values" $ do
    let eth = headOrError (pageTrades (decodeFixture fixture) Map.! "ETH/USD")
        missing = decodeFixture "{\"trades\":{\"SOL/USD\":[{\"i\":1,\"p\":1,\"s\":0,\"t\":\"2026-10-02T00:00:00Z\"}]}}"
        future = decodeFixture "{\"trades\":{\"SOL/USD\":[{\"i\":1,\"p\":1,\"s\":0,\"t\":\"2026-10-02T00:00:00Z\",\"tks\":\"NEW\"}]}}"
    tradeTakerSide eth `shouldBe` Nothing
    tradeTakerSide (headOrError (pageTrades missing Map.! "SOL/USD")) `shouldBe` Nothing
    tradeTakerSide (headOrError (pageTrades future Map.! "SOL/USD")) `shouldBe` Just "NEW"

  it "accepts empty trade pages, absent, null or empty continuation token" $ do
    let absent = decodeFixture "{\"trades\":{}}"
        explicit = decodeFixture "{\"trades\":{},\"next_page_token\":null}"
        empty = decodeFixture "{\"trades\":{},\"next_page_token\":\"\"}"
    mapM_ (\page -> do
      tradeCount page `shouldBe` 0
      pageNextToken page `shouldBe` Nothing) [absent, explicit, empty]

  it "preserves undocumented API fields in original JSON" $ do
    let page = decodeFixture fixture
        Right input = eitherDecodeStrict' fixture :: Either String Value
    pageOriginal page `shouldBe` input

  it "produces symbolized single trade records with precise numeric values" $ do
    let btc = headOrError (pageTrades (decodeFixture fixture) Map.! "BTC/USD")
        value = tradeToJson "BTC/USD" btc
    case value of
      object -> do
        -- Encoding as JSON must not round or quote numeric trade fields.
        let encoded = show object
        encoded `shouldSatisfy` (not . null)
        case eitherDecodeStrict' (toByteString value) :: Either String Value of
          Left errorMessage -> error errorMessage
          Right parsed -> parsed `shouldBe` value

  it "visits records incrementally, with symbol context" $ do
    observed <- newIORef ([] :: [(String, Integer)])
    forEachTrade
      (\symbol trade -> modifyIORef' observed (<> [(show symbol, tradeId trade)]))
      (decodeFixture fixture)
    values <- readIORef observed
    length values `shouldBe` 2

  it "rejects malformed pages, missing mandatory fields, and invalid numeric types" $
    mapM_ (\input -> decodeCryptoTradesPage input `shouldSatisfy` isLeft)
      [ "", "[]", "{}", "{broken", "{\"trades\":null}"
      , "{\"trades\":[1,2,3]}"
      , "{\"trades\":{\"BTC/USD\":[{\"p\":1,\"s\":2,\"t\":\"2026-10-02T00:00:00Z\"}]}}"
      , "{\"trades\":{\"BTC/USD\":[{\"i\":1,\"p\":\"one\",\"s\":2,\"t\":\"2026-10-02T00:00:00Z\"}]}}"
      , "{\"trades\":{\"BTC/USD\":[{\"i\":1,\"p\":1,\"s\":\"2\",\"t\":\"2026-10-02T00:00:00Z\"}]}}"
      ]

headOrError :: [a] -> a
headOrError (value : _) = value
headOrError [] = error "Missing expected trade"

toByteString :: Value -> ByteString
toByteString = Lazy.toStrict . Aeson.encode

{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.Crypto.QuoteSpec (spec) where

import Alpaca.Domain.Crypto.Quote
  ( CryptoQuote (..), CryptoQuotesPage (..), decodeCryptoQuotesPage
  , quoteCount, quoteToJson, forEachQuote
  )
import Data.Aeson (Value, eitherDecodeStrict')
import qualified Data.Aeson as Aeson
import Data.ByteString (ByteString)
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Lazy as Lazy
import Data.Either (isLeft)
import Data.IORef (modifyIORef', newIORef, readIORef)
import qualified Data.Map.Strict as Map
import Data.Scientific (FPFormat (Fixed), formatScientific)
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

sample :: ByteString
sample =
  "{\"quotes\":{\"BTC/USD\":[{\"ap\":29000.123456789012345678,"
    <> "\"as\":0.000000000000123456789,\"bp\":28999.987654321012345678,"
    <> "\"bs\":3.000000000000000001,\"t\":\"2026-10-02T00:00:00.123456789Z\","
    <> "\"future_quote_field\":true}],"
    <> "\"ETH/USD\":[{\"ap\":2200.5,\"as\":2,\"bp\":2200.4,\"bs\":0.25,"
    <> "\"t\":\"2026-10-02T00:00:00.234567891Z\"}]},"
    <> "\"next_page_token\":\"resume-token\",\"future_page_metadata\":42}"

decodeSample :: ByteString -> CryptoQuotesPage
decodeSample = either error id . decodeCryptoQuotesPage

spec :: Spec
spec = do
  it "decodes multiple symbols with exact bid/ask prices and sizes and nanosecond timestamps" $ do
    let page = decodeSample sample
        btc = headOrError (pageQuotes page Map.! "BTC/USD")
    quoteCount page `shouldBe` 2
    Map.size (pageQuotes page) `shouldBe` 2
    formatScientific Fixed Nothing (quoteAskPrice btc)
      `shouldBe` "29000.123456789012345678"
    formatScientific Fixed Nothing (quoteAskSize btc)
      `shouldBe` "0.000000000000123456789"
    formatScientific Fixed Nothing (quoteBidPrice btc)
      `shouldBe` "28999.987654321012345678"
    formatScientific Fixed Nothing (quoteBidSize btc)
      `shouldBe` "3.000000000000000001"
    quoteTimestamp btc `shouldBe` "2026-10-02T00:00:00.123456789Z"
    pageNextToken page `shouldBe` Just "resume-token"

  it "accepts empty quote pages and null, missing or empty continuation tokens" $ do
    let pages =
          [ decodeSample "{\"quotes\":{}}"
          , decodeSample "{\"quotes\":{},\"next_page_token\":null}"
          , decodeSample "{\"quotes\":{},\"next_page_token\":\"\"}"
          , decodeSample "{\"quotes\":{\"BTC/USD\":[]}}"
          ]
    mapM_ (\page -> do
      quoteCount page `shouldBe` 0
      pageNextToken page `shouldBe` Nothing) pages

  it "retains unknown provider properties in the complete original page" $ do
    let page = decodeSample sample
        parsed = either error id (eitherDecodeStrict' sample :: Either String Value)
    pageOriginal page `shouldBe` parsed
    Lazy.toStrict (Aeson.encode (pageOriginal page))
      `shouldSatisfy` (not . ByteString.null)

  it "outputs symbolized JSONL-compatible records with exact numeric values" $ do
    let btc = headOrError (pageQuotes (decodeSample sample) Map.! "BTC/USD")
        bytes = Lazy.toStrict (Aeson.encode (quoteToJson "BTC/USD" btc))
    let parsed = either error id (eitherDecodeStrict' bytes :: Either String Value)
    parsed `shouldBe` quoteToJson "BTC/USD" btc
    bytes `shouldSatisfy` (not . ByteString.null)

  it "visits each quote once, retaining the originating symbol" $ do
    events <- newIORef ([] :: [(String, String)])
    forEachQuote
      (\symbol quote -> modifyIORef' events
        (<> [(show symbol, show (quoteTimestamp quote))]))
      (decodeSample sample)
    observed <- readIORef events
    length observed `shouldBe` 2

  it "rejects malformed JSON, missing quote fields and incorrect JSON scalar types" $
    mapM_ (\input -> decodeCryptoQuotesPage input `shouldSatisfy` isLeft)
      [ "", "[]", "{}", "{broken", "{\"quotes\":null}"
      , "{\"quotes\":[1,2,3]}"
      , "{\"quotes\":{\"BTC/USD\":[{\"ap\":1,\"as\":2,\"bp\":3,\"bs\":4}]}}"
      , "{\"quotes\":{\"BTC/USD\":[{\"ap\":\"1\",\"as\":2,\"bp\":3,\"bs\":4,\"t\":\"2026-10-02T00:00:00Z\"}]}}"
      , "{\"quotes\":{\"BTC/USD\":[{\"ap\":1,\"as\":null,\"bp\":3,\"bs\":4,\"t\":\"2026-10-02T00:00:00Z\"}]}}"
      , "{\"quotes\":{\"BTC/USD\":[{\"ap\":1,\"as\":2,\"bp\":false,\"bs\":4,\"t\":\"2026-10-02T00:00:00Z\"}]}}"
      , "{\"quotes\":{\"BTC/USD\":[{\"ap\":1,\"as\":2,\"bp\":3,\"bs\":{},\"t\":\"2026-10-02T00:00:00Z\"}]}}"
      , "{\"quotes\":{\"BTC/USD\":[{\"ap\":1,\"as\":2,\"bp\":3,\"bs\":4,\"t\":25}]}}"
      ]

headOrError :: [a] -> a
headOrError (value:_) = value
headOrError [] = error "Missing expected quote"

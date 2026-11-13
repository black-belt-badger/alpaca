{-# LANGUAGE OverloadedStrings #-}

{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Crypto.BarsSpec (spec) where

import Alpaca.Command.Crypto.Bars
  ( BarsFormat (..)
  , BarsSort (..)
  , CryptoLocation (..)
  , instantParameter
  , locationParameter
  , parseBarsFormat
  , parseInstant
  , parseLocation
  , parseMaxPages
  , parsePageLimit
  , parsePageToken
  , parseSort
  , parseSymbols
  , parseTimeframe
  , timeframeParameter
  , validateDateRange
  )
import Data.Either (isLeft)
import qualified Data.Text as Text
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

spec :: Spec
spec = do
  it "accepts supported and allowlisted locations" $ do
    mapM_ (\(name, location) -> do
      parseLocation name `shouldBe` Right location
      locationParameter location `shouldBe` name)
      [("us", Us), ("us-1", Us1), ("us-2", Us2), ("eu-1", Eu1), ("bs-1", Bs1)]
    parseLocation "https://other-host" `shouldSatisfy` isLeft
    parseLocation "../us" `shouldSatisfy` isLeft

  it "parses multiple crypto symbols without converting slashes" $ do
    parseSymbols "BTC/USD, ETH/USD,SOL/USD"
      `shouldBe` Right ["BTC/USD", "ETH/USD", "SOL/USD"]
    parseSymbols "DOGE/USD" `shouldBe` Right ["DOGE/USD"]

  it "rejects absent, malformed, and injected symbols" $
    mapM_ (\input -> parseSymbols input `shouldSatisfy` isLeft)
      ["", "BTCUSD", "BTC/USD,", ",BTC/USD", "BTC/USD,,ETH/USD",
       "btc/USD", "BTC/US D", "BTC/USD&limit=10000",
       "BTC/USD/USDT", "../BTC/USD", "BTC/USD?sort=desc"]

  it "supports documented timeframe ranges and aliases" $
    mapM_ (\name -> fmap timeframeParameter (parseTimeframe name) `shouldBe` Right (Text.pack name))
      ["1Min", "5Min", "59Min", "1T", "59T", "1Hour", "23Hour", "12H",
       "1Day", "1D", "1Week", "1W", "1Month", "2Month", "3Month",
       "4Month", "6Month", "12Month", "12M"]

  it "rejects unsupported timeframe numbers and units" $
    mapM_ (\input -> parseTimeframe input `shouldSatisfy` isLeft)
      ["", "0Min", "60Min", "00Min", "1min", "24Hour", "2Day", "2Week",
       "5Month", "13M", "1Second", "1T?limit=10000", "1.5Hour"]

  it "accepts date-only and RFC3339 offsets with nanosecond precision" $ do
    let values =
          ["2026-10-02", "2026-10-02T00:00:00Z",
           "2026-10-02T00:00:00.123456789Z",
           "2026-10-02T02:00:00+02:00",
           "2026-10-02T02:00:00.987654321+02:00"]
    mapM_ (\value -> fmap instantParameter (parseInstant value) `shouldBe` Right (Text.pack value)) values

  it "rejects malformed dates and unzoned timestamps" $
    mapM_ (\value -> parseInstant value `shouldSatisfy` isLeft)
      ["", "today", "2026-02-30", "2026-13-01", "2026-10-02T00:00:00",
       "2026-10-02T00:00:00Z&limit=10000"]

  it "checks date ranges across timezone offsets" $ do
    let parse = either error id . parseInstant
    validateDateRange (Just (parse "2026-10-02T00:00:00Z"))
      (Just (parse "2026-10-02T02:00:00+02:00")) `shouldBe` Right ()
    validateDateRange (Just (parse "2026-10-02"))
      (Just (parse "2026-10-03")) `shouldBe` Right ()
    validateDateRange (Just (parse "2026-10-04")) (Just (parse "2026-10-02"))
      `shouldSatisfy` isLeft
    validateDateRange Nothing Nothing `shouldBe` Right ()

  it "bounds page size and number of pages" $ do
    mapM_ (\n -> parsePageLimit (show n) `shouldBe` Right n) [1, 1000, 10000]
    mapM_ (\n -> parseMaxPages (show n) `shouldBe` Right n) [1, 2, 20]
    mapM_ (\input -> parsePageLimit input `shouldSatisfy` isLeft)
      ["", "0", "10001", "-1", "1.5", "99999999999999999999999"]
    mapM_ (\input -> parseMaxPages input `shouldSatisfy` isLeft)
      ["", "0", "21", "99999999999999999999999"]

  it "accepts opaque pagination tokens but rejects controls and excessive length" $ do
    parsePageToken "abc/123+==" `shouldBe` Right "abc/123+=="
    mapM_ (\input -> parsePageToken input `shouldSatisfy` isLeft)
      ["", "has space", "has\nnewline", replicate 2049 'a']

  it "restricts output formats and sorts" $ do
    parseSort "asc" `shouldBe` Right BarsAsc
    parseSort "desc" `shouldBe` Right BarsDesc
    parseSort "random" `shouldSatisfy` isLeft
    parseBarsFormat "json" `shouldBe` Right BarsJson
    parseBarsFormat "jsonl" `shouldBe` Right BarsJsonl
    parseBarsFormat "csv" `shouldSatisfy` isLeft

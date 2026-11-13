{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Order.SubmitSpec (spec) where

import Alpaca.Command.Order.Submit
  ( SubmitCommand (..), SubmitSide (..), SubmitKind (..)
  , SubmitTimeInForce (..), PreparedOrder
  , parseSubmitSymbol, parseSubmitAmount, parseClientOrderId
  , parseSubmitSide, parseSubmitKind, parseSubmitTimeInForce
  , prepareOrder, submittedOrderBody
  , preparedPairValue, preparedClientIdValue )
import Data.Aeson (Value (..), eitherDecode, (.:))
import Data.Aeson.Types (parseEither)
import Data.Either (isLeft, isRight)
import Data.Text (Text)
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

sample :: SubmitCommand
sample = SubmitCommand
  { submitSymbol = either error id (parseSubmitSymbol "BTC/USD")
  , submitSide = SubmitBuy
  , submitKind = SubmitMarket
  , submitTimeInForce = SubmitGtc
  , submitQuantity = Just (either error id (parseSubmitAmount "0.000100001"))
  , submitNotional = Nothing
  , submitLimitPrice = Nothing
  , submitClientOrderId = either error id (parseClientOrderId "experiment-01")
  , submitConfirmed = False
  , submitOutput = Nothing
  }

prepared :: SubmitCommand -> PreparedOrder
prepared = either error id . prepareOrder

spec :: Spec
spec = do
  it "accepts exactly one safe uppercase crypto pair" $ do
    parseSubmitSymbol "BTC/USD" `shouldSatisfy` isRight
    parseSubmitSymbol "SOL/USDT" `shouldSatisfy` isRight
    mapM_ (\v -> parseSubmitSymbol v `shouldSatisfy` isLeft)
      [ "", "BTCUSD", "btc/USD", "BTC/USD,ETH/USD", "BTC/USD,", "BTC/USD#fragment"
      , "BTC/USD?side=sell", "BTC/USD;rm", "BTC/USD/USDT", "/USD", "BTC/"
      , "BTC%2FUSD", "BTC/U S D" ]

  it "preserves positive exact decimal spellings and forbids invalid amounts" $ do
    mapM_ (\v -> parseSubmitAmount v `shouldSatisfy` isRight)
      [ "1", "0.000000001", "1.200000000", "000.0001", "12345678901234567890.123456789" ]
    mapM_ (\v -> parseSubmitAmount v `shouldSatisfy` isLeft)
      [ "", "0", "0.000000000", "-1", "+1", ".5", "1.", "1.2345678901", "1e-8"
      , "NaN", "1.2.3", "1 0", "1\n2", "１２", "0x1", "1;echo", replicate 65 '1' ]

  it "requires a stable safe client-order-id with limited length" $ do
    mapM_ (\v -> parseClientOrderId v `shouldSatisfy` isRight)
      [ "experiment-01", "btc_2026:11.13", replicate 128 'A' ]
    mapM_ (\v -> parseClientOrderId v `shouldSatisfy` isLeft)
      [ "", "a b", "id\nsecret", "id/path", "id?symbol=BTC", replicate 129 'A'
      , "id😼", "id&command" ]

  it "recognizes only supported crypto side, kind, and TIF" $ do
    parseSubmitSide "buy" `shouldBe` Right SubmitBuy
    parseSubmitSide "sell" `shouldBe` Right SubmitSell
    parseSubmitKind "market" `shouldBe` Right SubmitMarket
    parseSubmitKind "limit" `shouldBe` Right SubmitLimit
    parseSubmitTimeInForce "gtc" `shouldBe` Right SubmitGtc
    parseSubmitTimeInForce "ioc" `shouldBe` Right SubmitIoc
    mapM_ (\s -> parseSubmitSide s `shouldSatisfy` isLeft) ["BUY", "short", "", "both"]
    mapM_ (\s -> parseSubmitKind s `shouldSatisfy` isLeft)
      ["stop_limit", "bracket", "trailing_stop", "MARKET", ""]
    mapM_ (\s -> parseSubmitTimeInForce s `shouldSatisfy` isLeft)
      ["day", "fok", "opg", "cls", "GTC", ""]

  it "accepts dry-run and confirmed market orders with quantity" $ do
    prepareOrder sample `shouldSatisfy` isRight
    prepareOrder (sample { submitConfirmed = True }) `shouldSatisfy` isRight

  it "accepts notional crypto market orders but never qty and notional together" $ do
    let notional = Just (either error id (parseSubmitAmount "25.12"))
        byNotional = sample { submitQuantity = Nothing, submitNotional = notional }
    prepareOrder byNotional `shouldSatisfy` isRight
    prepareOrder (sample { submitNotional = notional })
      `shouldBe` Left "--qty and --notional cannot be combined"
    prepareOrder (sample { submitQuantity = Nothing })
      `shouldBe` Left "Exactly one of --qty or --notional is required"

  it "enforces USD-quoted crypto notional precision without rounding" $ do
    let btc = sample
          { submitQuantity = Nothing
          , submitNotional = Just (either error id (parseSubmitAmount "25.123")) }
    prepareOrder btc `shouldBe`
      Left "USD-quoted crypto notional supports at most 2 decimal places"
    let nonUsd = btc
          { submitSymbol = either error id (parseSubmitSymbol "ETH/BTC")
          , submitNotional = Just (either error id (parseSubmitAmount "0.123456789")) }
    prepareOrder nonUsd `shouldSatisfy` isRight

  it "accepts limit orders only with qty and a positive limit price" $ do
    let limit = sample
          { submitKind = SubmitLimit
          , submitLimitPrice = Just (either error id (parseSubmitAmount "120000.123456789"))
          }
    prepareOrder limit `shouldSatisfy` isRight
    prepareOrder (limit { submitQuantity = Nothing
                        , submitNotional = Just (either error id (parseSubmitAmount "50")) })
      `shouldBe` Left "Limit orders require --qty; --notional is supported only for market orders"
    prepareOrder (sample { submitKind = SubmitLimit })
      `shouldBe` Left "Limit orders require --limit-price"
    prepareOrder (sample { submitLimitPrice = submitLimitPrice limit })
      `shouldBe` Left "--limit-price is only allowed for limit orders"

  it "rejects --out in dry-run mode instead of creating ambiguous files" $ do
    prepareOrder (sample { submitOutput = Just "order.json" })
      `shouldBe` Left "--out requires --confirm; dry runs do not write response files"
    prepareOrder (sample { submitConfirmed = True, submitOutput = Just "order.json" })
      `shouldSatisfy` isRight

  it "serializes exact ASCII decimal STRINGS, never JSON floating point values" $ do
    let order = prepared sample
    preparedPairValue order `shouldBe` "BTC/USD"
    preparedClientIdValue order `shouldBe` "experiment-01"
    case eitherDecode (submittedOrderBody order) of
      Left problem -> fail problem
      Right (Object fields) -> do
        let field name = parseEither (.: name) fields :: Either String Text
        field "symbol" `shouldBe` Right "BTC/USD"
        field "side" `shouldBe` Right "buy"
        field "type" `shouldBe` Right "market"
        field "time_in_force" `shouldBe` Right "gtc"
        field "qty" `shouldBe` Right "0.000100001"
        field "client_order_id" `shouldBe` Right "experiment-01"
        (parseEither (.: "notional") fields :: Either String Text) `shouldSatisfy` isLeft
        (parseEither (.: "limit_price") fields :: Either String Text) `shouldSatisfy` isLeft
      Right _ -> fail "Expected an object request body"

  it "emits only notional for a notional market order" $ do
    let order = prepared (sample
          { submitQuantity = Nothing
          , submitNotional = Just (either error id (parseSubmitAmount "25.12")) })
    case eitherDecode (submittedOrderBody order) of
      Right (Object fields) -> do
        let notional = parseEither (.: "notional") fields :: Either String Text
        notional `shouldBe` Right "25.12"
        (parseEither (.: "qty") fields :: Either String Text) `shouldSatisfy` isLeft
      _ -> fail "Expected JSON object"

  it "writes the limit price as a quoted decimal, never a floating point" $ do
    let order = prepared (sample
          { submitKind = SubmitLimit
          , submitLimitPrice = Just (either error id (parseSubmitAmount "80000.100000001")) })
    case eitherDecode (submittedOrderBody order) of
      Right (Object fields) -> do
        let field key = parseEither (.: key) fields :: Either String Text
        field "type" `shouldBe` Right "limit"
        field "limit_price" `shouldBe` Right "80000.100000001"
        field "qty" `shouldBe` Right "0.000100001"
      _ -> fail "Expected JSON object"

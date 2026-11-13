{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Order.Submit.ParserSpec (spec) where

import Alpaca.Command (Command (..))
import Alpaca.Command.Order (OrderCommand (..))
import Alpaca.Command.Order.Submit
  ( SubmitCommand (..), SubmitSide (..), SubmitKind (..), SubmitTimeInForce (..)
  , parseSubmitSymbol, parseSubmitAmount, parseClientOrderId )
import Alpaca.Command.Parser (commandParserInfo)
import Options.Applicative (defaultPrefs, execParserPure, getParseResult)
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)
import Data.Either (isLeft)

sample :: [String]
sample = ["order", "submit", "--symbol", "BTC/USD", "--side", "buy",
  "--type", "market", "--qty", "0.0001", "--client-order-id", "test-id-01"]

parse :: [String] -> Maybe Command
parse = getParseResult . execParserPure defaultPrefs commandParserInfo

spec :: Spec
spec = do
  it "parses a default dry-run crypto market order" $ do
    let expected = SubmitCommand
          { submitSymbol = either error id (parseSubmitSymbol "BTC/USD")
          , submitSide = SubmitBuy
          , submitKind = SubmitMarket
          , submitTimeInForce = SubmitGtc
          , submitQuantity = Just (either error id (parseSubmitAmount "0.0001"))
          , submitNotional = Nothing
          , submitLimitPrice = Nothing
          , submitClientOrderId = either error id (parseClientOrderId "test-id-01")
          , submitConfirmed = False
          , submitOutput = Nothing
          }
    parse sample `shouldBe` Just (Order (SubmitOrder expected))

  it "parses a market sell with quoted notional, IOC and explicit paper confirmation" $ do
    let options = ["order", "submit", "--symbol", "ETH/USD",
          "--side", "sell", "--type", "market", "--time-in-force", "ioc",
          "--notional", "25.12", "--client-order-id", "medea:case-2",
          "--confirm", "--out", "paper-order.json"]
    case parse options of
      Just (Order (SubmitOrder cmd)) -> do
        submitSymbol cmd `shouldBe` either error id (parseSubmitSymbol "ETH/USD")
        submitSide cmd `shouldBe` SubmitSell
        submitKind cmd `shouldBe` SubmitMarket
        submitTimeInForce cmd `shouldBe` SubmitIoc
        submitNotional cmd `shouldBe` Just (either error id (parseSubmitAmount "25.12"))
        submitQuantity cmd `shouldBe` Nothing
        submitConfirmed cmd `shouldBe` True
        submitOutput cmd `shouldBe` Just "paper-order.json"
      _ -> fail "Expected a parsed paper submit command"

  it "parses a limit order with exact price but no hidden confirmation" $ do
    let options = ["order", "submit", "--symbol", "SOL/USD",
          "--side", "buy", "--type", "limit", "--qty", "3.123456789",
          "--limit-price", "180.100000001", "--client-order-id", "test-lmt-1"]
    case parse options of
      Just (Order (SubmitOrder cmd)) -> do
        submitKind cmd `shouldBe` SubmitLimit
        submitLimitPrice cmd `shouldBe` Just (either error id (parseSubmitAmount "180.100000001"))
        submitConfirmed cmd `shouldBe` False
      _ -> fail "Expected typed limit order"

  it "rejects missing essential flags before loading credentials" $ do
    mapM_ (\missing -> parse missing `shouldBe` Nothing)
      [ ["order", "submit"]
      , ["order", "submit", "--symbol", "BTC/USD"]
      , ["order", "submit", "--side", "buy"]
      , ["order", "submit", "--symbol", "BTC/USD", "--side", "buy", "--type", "market"]
      , ["order", "submit", "--symbol", "BTC/USD", "--type", "market", "--qty", "1"]
      , ["order", "submit", "--symbol", "BTC/USD", "--side", "buy", "--qty", "1"]
      ]

  it "rejects invalid symbol, kind, TIF, amount and client ID lexically" $ do
    mapM_ (\(flag, value) ->
      parse (sample <> [flag, value]) `shouldBe` Nothing)
      [ ("--symbol", "../api"), ("--symbol", "BTCUSD")
      , ("--side", "short"), ("--side", "BUY")
      , ("--type", "stop"), ("--time-in-force", "day")
      , ("--qty", "-1"), ("--qty", "1e10"), ("--qty", "1.1234567890")
      , ("--notional", "NaN"), ("--limit-price", "bad")
      , ("--client-order-id", "has spaces")
      , ("--client-order-id", "id/../../orders") ]

  it "rejects unsupported flags and unknown subcommands" $ do
    parse (sample <> ["--live"]) `shouldBe` Nothing
    parse (sample <> ["--url", "https://api.alpaca.markets"]) `shouldBe` Nothing
    parse ["order", "replace", "abc"] `shouldBe` Nothing

  it "parses positive decimals without normalizing user input" $ do
    let exact = parseSubmitAmount "0000001.010000001"
    exact `shouldSatisfy` (not . isLeft)

{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Order.Submit.RunSpec (spec) where

import Alpaca.Client (AlpacaError (..))
import Alpaca.Command.Order.Submit
  ( SubmitCommand (..), SubmitSide (..), SubmitKind (..), SubmitTimeInForce (..)
  , PreparedOrder, parseSubmitSymbol, parseSubmitAmount, parseClientOrderId, prepareOrder )
import Alpaca.Command.Order.Submit.Run (decodeSubmitResult, submitErrorMessage, dryRunMessage)
import Alpaca.Domain.Order (Order (..), OrderState (..))
import Data.ByteString (ByteString)
import Data.List (isInfixOf)
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

args :: SubmitCommand
args = SubmitCommand
  { submitSymbol = either error id (parseSubmitSymbol "BTC/USD")
  , submitSide = SubmitBuy
  , submitKind = SubmitMarket
  , submitTimeInForce = SubmitGtc
  , submitQuantity = Just (either error id (parseSubmitAmount "0.000100001"))
  , submitNotional = Nothing
  , submitLimitPrice = Nothing
  , submitClientOrderId = either error id (parseClientOrderId "kirke-test-001")
  , submitConfirmed = False
  , submitOutput = Nothing
  }

prepared :: PreparedOrder
prepared = either error id (prepareOrder args)

payload :: ByteString
payload =
  "{\"id\":\"11111111-2222-4333-8444-555555555555\",\"client_order_id\":\"kirke-test-001\",\"symbol\":\"BTC/USD\",\"status\":\"new\",\"qty\":\"0.000100001\",\"unknown_decimal\":0.000000000000001234567890123456789}"

spec :: Spec
spec = do
  it "prints an unmistakable offline dry run without credential loading" $ do
    let preview = dryRunMessage prepared
    preview `shouldSatisfy` isInfixOf "DRY RUN"
    preview `shouldSatisfy` isInfixOf "no credentials loaded"
    preview `shouldSatisfy` isInfixOf "no order submitted"
    preview `shouldSatisfy` isInfixOf "\"client_order_id\":\"kirke-test-001\""
    preview `shouldSatisfy` isInfixOf "\"qty\":\"0.000100001\""
    preview `shouldSatisfy` (not . isInfixOf "APCA-API-SECRET-KEY")

  it "decodes only a matching order and returns original response bytes" $ do
    case decodeSubmitResult prepared (Right payload) of
      Left problem -> fail problem
      Right (order, body) -> do
        orderClientOrderId order `shouldBe` Just "kirke-test-001"
        orderState order `shouldBe` StateNew
        orderQty order `shouldBe` Just "0.000100001"
        body `shouldBe` payload

  it "rejects a mismatched or omitted client_order_id without leaking it" $ do
    forInvalid
      "{\"id\":\"123\",\"client_order_id\":\"SENSITIVE-OTHER\",\"status\":\"new\"}"
      "Submission response client_order_id does not match. Check paper orders before retrying."
    forInvalid
      "{\"id\":\"123\",\"status\":\"new\"}"
      "Submission response client_order_id does not match. Check paper orders before retrying."

  it "rejects arrays, scalars, malformed JSON and missing required fields" $ do
    mapM_ (\body -> forInvalid body
      "Invalid paper-order submission response. Check paper orders before retrying.")
      [ "[]", "null", "\"PRIVATE_RAW_DATA\"", "42", "not-json", "{}"
      , "{\"id\":\"abc\"}", "{\"status\":\"new\"}"
      , "{\"id\":\"abc\",\"status\":true}" ]

  it "distinguishes credentials, permission, validation and rate limits" $ do
    submitErrorMessage (UnexpectedStatus 401)
      `shouldBe` "Alpaca paper API rejected credentials (HTTP 401). No response body exposed."
    submitErrorMessage (UnexpectedStatus 403)
      `shouldBe` "Alpaca paper order rejected (HTTP 403; check permissions or buying power)."
    submitErrorMessage (UnexpectedStatus 422)
      `shouldBe` "Alpaca paper order rejected (HTTP 422; check order parameters and asset rules)."
    submitErrorMessage (UnexpectedStatus 429)
      `shouldBe` "Alpaca paper API rate-limited submission (HTTP 429). Check paper orders before retrying."

  it "warns on uncertain network/5xx outcomes without suggesting blind retries" $ do
    submitErrorMessage ConnectionFailed `shouldSatisfy` isInfixOf "result unknown"
    submitErrorMessage ConnectionFailed `shouldSatisfy` isInfixOf "Check existing paper orders"
    submitErrorMessage (UnexpectedStatus 503) `shouldSatisfy` isInfixOf "before retrying"
    submitErrorMessage (UnexpectedStatus 504) `shouldSatisfy` isInfixOf "before retrying"
    submitErrorMessage (UnexpectedStatus 400)
      `shouldBe` "Alpaca paper order submission returned HTTP 400."

  it "does not echo private response data or server IDs on errors" $ do
    case decodeSubmitResult prepared
         (Right "{\"id\":\"secret-id\",\"status\":\"new\",\"client_order_id\":\"NEVER-ECHO\"}") of
      Left err -> do
        err `shouldSatisfy` (not . isInfixOf "NEVER-ECHO")
        err `shouldSatisfy` (not . isInfixOf "secret-id")
      Right _ -> fail "Mismatched order was accepted"

  it "propagates typed HTTP errors without decoding an untrusted response" $ do
    case decodeSubmitResult prepared (Left ConnectionFailed) of
      Left err -> err `shouldBe` submitErrorMessage ConnectionFailed
      Right _ -> fail "Unexpected success"
    case decodeSubmitResult prepared (Left (UnexpectedStatus 500)) of
      Left err -> err `shouldBe` submitErrorMessage (UnexpectedStatus 500)
      Right _ -> fail "Unexpected success"

forInvalid :: ByteString -> String -> IO ()
forInvalid raw expected =
  case decodeSubmitResult prepared (Right raw) of
    Left message -> do
      message `shouldBe` expected
      message `shouldSatisfy` (not . isInfixOf "PRIVATE")
      message `shouldSatisfy` (not . isInfixOf "SENSITIVE")
    Right _ -> fail "Malformed order response was accepted"

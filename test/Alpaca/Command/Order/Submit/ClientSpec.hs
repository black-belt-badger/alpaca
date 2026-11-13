{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Order.Submit.ClientSpec (spec) where

import Alpaca.Client
  ( AlpacaError (..), submitOrderRequest, interpretPaperResponse )
import Alpaca.Command.Order.Submit
  ( SubmitCommand (..), SubmitSide (..), SubmitKind (..), SubmitTimeInForce (..)
  , PreparedOrder, parseSubmitSymbol, parseSubmitAmount, parseClientOrderId
  , prepareOrder, submittedOrderBody )
import Alpaca.Credentials (Credentials (..))
import Data.Aeson (Value, eitherDecode)
import qualified Data.ByteString.Char8 as Char8
import qualified Data.ByteString.Lazy as Lazy
import Network.HTTP.Client (Request (..), RequestBody (..))
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

prepared :: PreparedOrder
prepared = either error id $ prepareOrder SubmitCommand
  { submitSymbol = either error id (parseSubmitSymbol "BTC/USD")
  , submitSide = SubmitBuy
  , submitKind = SubmitMarket
  , submitTimeInForce = SubmitGtc
  , submitQuantity = Just (either error id (parseSubmitAmount "0.000000001"))
  , submitNotional = Nothing
  , submitLimitPrice = Nothing
  , submitClientOrderId = either error id (parseClientOrderId "fixed-case-001")
  , submitConfirmed = True
  , submitOutput = Nothing
  }

spec :: Spec
spec = do
  let credentials = Credentials "synthetic-key" "synthetic-secret"
      request = submitOrderRequest credentials prepared

  it "sends POST only to the fixed Alpaca PAPER host with no redirects" $ do
    method request `shouldBe` "POST"
    secure request `shouldBe` True
    host request `shouldBe` "paper-api.alpaca.markets"
    port request `shouldBe` 443
    path request `shouldBe` "/v2/orders"
    queryString request `shouldBe` ""
    redirectCount request `shouldBe` 0

  it "includes the existing protected credentials and application/json Content-Type" $ do
    lookup "APCA-API-KEY-ID" (requestHeaders request) `shouldBe` Just "synthetic-key"
    lookup "APCA-API-SECRET-KEY" (requestHeaders request) `shouldBe` Just "synthetic-secret"
    lookup "Content-Type" (requestHeaders request) `shouldBe` Just "application/json"

  it "writes exact decimal strings into one JSON request body" $ do
    case requestBody request of
      RequestBodyLBS body -> do
        body `shouldBe` submittedOrderBody prepared
        let decoded = eitherDecode body :: Either String Value
        decoded `shouldSatisfy` either (const False) (const True)
        Lazy.toStrict body `shouldSatisfy` Char8.isInfixOf "\"qty\":\"0.000000001\""
        Lazy.toStrict body `shouldSatisfy` Char8.isInfixOf "\"client_order_id\":\"fixed-case-001\""
      _ -> fail "Expected a complete lazy JSON request body"

  it "never includes credentials in the JSON payload or request URL" $ do
    case requestBody request of
      RequestBodyLBS body -> do
        Lazy.toStrict body `shouldSatisfy` (not . Char8.isInfixOf "synthetic-secret")
        Lazy.toStrict body `shouldSatisfy` (not . Char8.isInfixOf "synthetic-key")
      _ -> fail "Expected JSON request body"
    path request `shouldBe` "/v2/orders"
    queryString request `shouldBe` ""

  it "handles 200 as potential success and errors without returning provider text" $ do
    interpretPaperResponse 200 "{\"id\":\"order\"}" `shouldBe` Right "{\"id\":\"order\"}"
    interpretPaperResponse 201 "{}" `shouldBe` Right "{}"
    interpretPaperResponse 401 "PRIVATE" `shouldBe` Left (UnexpectedStatus 401)
    interpretPaperResponse 403 "PRIVATE" `shouldBe` Left (UnexpectedStatus 403)
    interpretPaperResponse 422 "PRIVATE" `shouldBe` Left (UnexpectedStatus 422)
    interpretPaperResponse 429 "PRIVATE" `shouldBe` Left (UnexpectedStatus 429)
    interpretPaperResponse 503 "PRIVATE" `shouldBe` Left (UnexpectedStatus 503)

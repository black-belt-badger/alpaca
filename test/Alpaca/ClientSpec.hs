{-# LANGUAGE OverloadedStrings #-}

module Alpaca.ClientSpec (spec) where

import Alpaca.Client
  ( AlpacaError (..)
  , accountRequest
  , assetsRequest
  , ordersRequest
  , positionsRequest
  , interpretPaperResponse
  , alpacaErrorMessage
  , interpretAccountResponse
  )
import Alpaca.Command.Assets (AssetClass (..), AssetStatus (..))
import Alpaca.Command.Orders (OrdersCommand (..), OrderFilter (..), OrderDirection (..))
import Alpaca.Credentials (Credentials (..))
import Network.HTTP.Client (Request (..))
import Test.Hspec (Spec, it, shouldBe)

spec :: Spec
spec = do
  let credentials = Credentials "example-key" "example-secret"
      request = accountRequest credentials

  it "uses HTTPS to request the paper trading account" $ do
    method request `shouldBe` "GET"
    secure request `shouldBe` True
    host request `shouldBe` "paper-api.alpaca.markets"
    port request `shouldBe` 443
    path request `shouldBe` "/v2/account"
    redirectCount request `shouldBe` 0

  it "uses the same paper-only settings to request positions" $ do
    let positions = positionsRequest credentials
    method positions `shouldBe` "GET"
    secure positions `shouldBe` True
    host positions `shouldBe` "paper-api.alpaca.markets"
    port positions `shouldBe` 443
    path positions `shouldBe` "/v2/positions"
    redirectCount positions `shouldBe` 0
    requestHeaders positions `shouldBe` requestHeaders request

  it "requests crypto assets explicitly, never implicit equities" $ do
    let assets = assetsRequest credentials Crypto Nothing
    method assets `shouldBe` "GET"
    secure assets `shouldBe` True
    host assets `shouldBe` "paper-api.alpaca.markets"
    port assets `shouldBe` 443
    path assets `shouldBe` "/v2/assets"
    queryString assets `shouldBe` "?asset_class=crypto"
    requestHeaders assets `shouldBe` requestHeaders request
    redirectCount assets `shouldBe` 0

  it "constructs filtered equity asset requests" $ do
    let assets = assetsRequest credentials UsEquity (Just Active)
    queryString assets `shouldBe` "?asset_class=us_equity&status=active"

  it "supports inactive and all status filters" $ do
    queryString (assetsRequest credentials Crypto (Just Inactive))
      `shouldBe` "?asset_class=crypto&status=inactive"
    queryString (assetsRequest credentials Crypto (Just All))
      `shouldBe` "?asset_class=crypto&status=all"

  it "constructs paper-only order requests with explicit defaults" $ do
    let orders = ordersRequest credentials (OrdersCommand OpenOrders Nothing [] Descending Nothing)
    method orders `shouldBe` "GET"
    secure orders `shouldBe` True
    host orders `shouldBe` "paper-api.alpaca.markets"
    path orders `shouldBe` "/v2/orders"
    redirectCount orders `shouldBe` 0
    requestHeaders orders `shouldBe` requestHeaders request
    queryString orders `shouldBe` "?status=open&direction=desc"

  it "encodes order filters, comma-separated symbols and crypto slashes" $ do
    let orders = ordersRequest credentials
          (OrdersCommand AllOrders (Just 500) ["BTC/USD", "AAPL"] Ascending Nothing)
    queryString orders `shouldBe`
      "?status=all&direction=asc&limit=500&symbols=BTC%2FUSD%2CAAPL"

  it "supports closed orders and a single symbol" $
    queryString (ordersRequest credentials
      (OrdersCommand ClosedOrders (Just 1) ["SOLUSD"] Descending Nothing))
      `shouldBe` "?status=closed&direction=desc&limit=1&symbols=SOLUSD"

  it "does not return order error response bodies" $ do
    interpretPaperResponse 403 "private error" `shouldBe` Left (UnexpectedStatus 403)
    interpretPaperResponse 429 "rate limit details" `shouldBe` Left (UnexpectedStatus 429)

  it "returns the complete positions JSON body on HTTP 200" $
    interpretPaperResponse 200 "[]"
      `shouldBe` Right "[]"

  it "rejects redirected requests so credentials are never forwarded" $
    interpretPaperResponse 302 "redirect target" `shouldBe` Left (UnexpectedStatus 302)

  it "rejects HTTP errors without exposing the response body" $ do
    interpretPaperResponse 401 "private content" `shouldBe` Left (UnexpectedStatus 401)
    interpretPaperResponse 503 "provider details" `shouldBe` Left (UnexpectedStatus 503)

  it "sets both authentication headers" $ do
    lookup "APCA-API-KEY-ID" (requestHeaders request)
      `shouldBe` Just "example-key"
    lookup "APCA-API-SECRET-KEY" (requestHeaders request)
      `shouldBe` Just "example-secret"

  it "returns the unmodified response body on HTTP 200" $
    interpretAccountResponse 200 "{\"status\":\"ACTIVE\"}"
      `shouldBe` Right "{\"status\":\"ACTIVE\"}"

  it "rejects HTTP 401 without returning the response body" $
    interpretAccountResponse 401 "potentially sensitive error body"
      `shouldBe` Left (UnexpectedStatus 401)

  it "rejects server errors" $
    interpretAccountResponse 503 "unavailable"
      `shouldBe` Left (UnexpectedStatus 503)

  it "returns a safe diagnostic for invalid credentials" $
    alpacaErrorMessage (UnexpectedStatus 401)
      `shouldBe` "Alpaca paper API rejected the credentials (HTTP 401)."

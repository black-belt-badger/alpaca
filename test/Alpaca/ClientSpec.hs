{-# LANGUAGE OverloadedStrings #-}

module Alpaca.ClientSpec (spec) where

import Alpaca.Client
  ( AlpacaError (..)
  , accountRequest
  , assetsRequest
  , ordersRequest
  , orderRequest
  , positionsRequest
  , interpretPaperResponse
  , alpacaErrorMessage
  , interpretAccountResponse
  )
import Alpaca.Command.Assets (AssetClass (..), AssetStatus (..))
import Alpaca.Command.Order (OrderGetCommand (..), parseOrderId)
import Alpaca.Command.Orders (OrderDirection (..), OrderStatus (..), OrdersCommand (..))
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

  it "requests open orders from the paper endpoint with safe defaults" $ do
    let orders = ordersRequest credentials (OrdersCommand OrdersOpen Nothing Nothing Desc Nothing)
    method orders `shouldBe` "GET"
    secure orders `shouldBe` True
    host orders `shouldBe` "paper-api.alpaca.markets"
    port orders `shouldBe` 443
    path orders `shouldBe` "/v2/orders"
    redirectCount orders `shouldBe` 0
    queryString orders `shouldBe` "?status=open&direction=desc"
    requestHeaders orders `shouldBe` requestHeaders request

  it "encodes filtered orders, including multiple symbols and sort direction" $ do
    let orders = ordersRequest credentials (OrdersCommand OrdersAll (Just 500) (Just ["BTCUSD", "AAPL"]) Asc Nothing)
    queryString orders `shouldBe` "?status=all&limit=500&symbols=BTCUSD%2CAAPL&direction=asc"

  it "uses a validated UUID to fetch a single paper order, without query by default" $ do
    let uuid = "9275f66a-0a1b-4a22-8c55-167416c7cf14"
        orderId = either error id (parseOrderId uuid)
        order = orderRequest credentials (OrderGetCommand orderId False Nothing)
    method order `shouldBe` "GET"
    secure order `shouldBe` True
    host order `shouldBe` "paper-api.alpaca.markets"
    port order `shouldBe` 443
    path order `shouldBe` "/v2/orders/9275f66a-0a1b-4a22-8c55-167416c7cf14"
    queryString order `shouldBe` ""
    redirectCount order `shouldBe` 0
    requestHeaders order `shouldBe` requestHeaders request

  it "only includes nested=true when explicitly requested" $ do
    let orderId = either error id (parseOrderId "9275f66a-0a1b-4a22-8c55-167416c7cf14")
        order = orderRequest credentials (OrderGetCommand orderId True Nothing)
    queryString order `shouldBe` "?nested=true"

  it "distinguishes HTTP 404 from 401 without exposing provider body" $ do
    interpretPaperResponse 404 "private provider error" `shouldBe` Left (UnexpectedStatus 404)
    interpretPaperResponse 401 "private provider error" `shouldBe` Left (UnexpectedStatus 401)

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

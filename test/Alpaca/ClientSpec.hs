{-# LANGUAGE OverloadedStrings #-}

module Alpaca.ClientSpec (spec) where

import Alpaca.Client
  ( AlpacaError (..)
  , accountRequest
  , alpacaErrorMessage
  , interpretAccountResponse
  )
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

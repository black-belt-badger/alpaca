{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Order.RunSpec (spec) where

import Alpaca.Client (AlpacaError (..))
import Alpaca.Command.Order.Run (orderErrorMessage)
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

spec :: Spec
spec = do
  it "distinguishes an unknown order from other HTTP errors" $
    orderErrorMessage (UnexpectedStatus 404)
      `shouldBe` "Alpaca paper order not found (HTTP 404)."

  it "preserves the explicit authentication error for HTTP 401" $
    orderErrorMessage (UnexpectedStatus 401)
      `shouldBe` "Alpaca paper API rejected the credentials (HTTP 401)."

  it "reports HTTP 403 and 503 without including provider response bodies" $ do
    orderErrorMessage (UnexpectedStatus 403)
      `shouldBe` "Alpaca paper API returned HTTP 403."
    orderErrorMessage (UnexpectedStatus 503)
      `shouldBe` "Alpaca paper API returned HTTP 503."

  it "does not echo the request or credentials on connection failure" $
    orderErrorMessage ConnectionFailed
      `shouldSatisfy` (not . ("example-secret" `elem`) . words)

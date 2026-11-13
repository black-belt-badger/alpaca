{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Diagnostics.AccountSpec (spec) where

import Alpaca.Diagnostics (Finding (..), Severity (..), severityValue)
import Alpaca.Diagnostics.Account (accountFindings)
import Alpaca.Domain.Account (decodeAccount)
import Data.ByteString (ByteString)
import qualified Data.Text as Text
import Test.Hspec (Spec, describe, it, shouldBe, shouldSatisfy)

codes :: ByteString -> [(Text.Text, Severity, Text.Text)]
codes response =
  let account = either error id (decodeAccount response)
   in map (\f -> (findingCode f, findingSeverity f, findingPath f)) (accountFindings account)

spec :: Spec
spec = describe "Pure account findings shared with Medea" $ do
  it "defines stable lowercase severity labels" $
    map severityValue [Info, Warning, Error] `shouldBe` ["info", "warning", "error"]

  it "does not claim trading eligibility from ACTIVE plus explicit unblocked flags" $
    codes "{\"id\":\"secret\",\"status\":\"ACTIVE\",\"trading_blocked\":false,\"crypto_status\":\"ACTIVE\"}"
      `shouldBe` []

  it "reports trading blocked even when account status is ACTIVE" $
    codes "{\"id\":\"secret\",\"status\":\"ACTIVE\",\"trading_blocked\":true,\"crypto_status\":\"ACTIVE\"}"
      `shouldBe` [("ACCOUNT_TRADING_BLOCKED", Error, "trading_blocked")]

  it "distinguishes nonactive account status, unknown flag and separate crypto status" $
    codes "{\"id\":\"secret\",\"status\":\"LIMITED\",\"crypto_status\":\"PAPER_ONLY\"}"
      `shouldBe`
        [ ("ACCOUNT_STATUS_NOT_ACTIVE", Warning, "status")
        , ("ACCOUNT_TRADING_BLOCKED_UNKNOWN", Info, "trading_blocked")
        , ("ACCOUNT_CRYPTO_STATUS_NOT_ACTIVE", Info, "crypto_status")
        ]

  it "does not invent crypto status findings for missing optional field" $
    codes "{\"id\":\"secret\",\"status\":\"ACTIVE\",\"trading_blocked\":false}"
      `shouldBe` []

  it "never embeds private account identifiers, cash or upstream values" $ do
    let account = either error id (decodeAccount
          "{\"id\":\"PRIVATE-ID-123\",\"account_number\":\"PRIVATE-ACCOUNT\",\"cash\":\"123456.789\",\"status\":\"ACTIVE\",\"trading_blocked\":true}")
        findings = accountFindings account
        rendered = Text.pack (show findings)
    findings `shouldSatisfy` (not . null)
    rendered `shouldSatisfy` (not . Text.isInfixOf "PRIVATE-ID-123")
    rendered `shouldSatisfy` (not . Text.isInfixOf "PRIVATE-ACCOUNT")
    rendered `shouldSatisfy` (not . Text.isInfixOf "123456.789")

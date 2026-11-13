{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Account.UnixSpec (spec) where

import Alpaca.Command.Account (AccountCommand (..), AccountFormat (..))
import Alpaca.Command.Account.Run (prepareAccountOutput, renderAccountFindings, writeAccountBytes)
import Alpaca.Diagnostics (Finding (..), Severity (..))
import Control.Exception (IOException, try)
import qualified Data.ByteString as Bytes
import qualified Data.Text as Text
import Test.Hspec (Spec, describe, it, shouldBe, shouldSatisfy)
import System.IO (hClose)
import System.Posix.IO (closeFd, createPipe, fdToHandle)

-- Identical fabricated inputs and expected finding codes to Medea.
blockedAccount :: Bytes.ByteString
blockedAccount = "{\"id\":\"PRIVATE_ACCOUNT_ID\",\"account_number\":\"SECRET-0001\",\"status\":\"ACTIVE\",\"crypto_status\":\"ACTIVE\",\"trading_blocked\":true,\"cash\":\"12.00000000000000000001\",\"future_numeric\":0.12345678901234567890123456789}"

limitedAccount :: Bytes.ByteString
limitedAccount = "{\"id\":\"PRIVATE_ACCOUNT_ID\",\"status\":\"LIMITED\",\"crypto_status\":\"PAPER_ONLY\"}"

options :: AccountFormat -> Bool -> AccountCommand
options format' check = AccountCommand Nothing format' check

prepared :: AccountFormat -> Bool -> Bytes.ByteString -> (Bytes.ByteString, [Finding])
prepared format' check = either error id . prepareAccountOutput (options format' check)

spec :: Spec
spec = describe "account stdout JSON and stderr findings contract" $ do
  it "defaults to the same familiar human summary with no diagnostics" $ do
    let (output, findings) = prepared AccountText False blockedAccount
    output `shouldSatisfy` Bytes.isInfixOf "Kirke"
    output `shouldSatisfy` Bytes.isInfixOf "Trading blocked: yes\n"
    findings `shouldBe` []

  it "passes through provider JSON byte-for-byte with exact decimal literals and unknown fields" $ do
    let (output, findings) = prepared AccountJson False blockedAccount
    output `shouldBe` blockedAccount
    findings `shouldBe` []

  it "--check never contaminates a JSON stream; findings remain separate and factual" $ do
    let (output, findings) = prepared AccountJson True blockedAccount
    output `shouldBe` blockedAccount
    map (\finding -> (findingCode finding, findingSeverity finding, findingPath finding)) findings
      `shouldBe` [("ACCOUNT_TRADING_BLOCKED", Error, "trading_blocked")]
    renderAccountFindings findings
      `shouldBe` "ERROR ACCOUNT_TRADING_BLOCKED (trading_blocked): Alpaca reports trading_blocked=true.\n"

  it "check reports independent unknown and non-active state without claiming order rejection" $ do
    let (output, findings) = prepared AccountText True limitedAccount
        diagnostic = renderAccountFindings findings
    output `shouldSatisfy` Bytes.isInfixOf "Status: LIMITED\n"
    map findingCode findings `shouldBe`
      [ "ACCOUNT_STATUS_NOT_ACTIVE"
      , "ACCOUNT_TRADING_BLOCKED_UNKNOWN"
      , "ACCOUNT_CRYPTO_STATUS_NOT_ACTIVE"
      ]
    diagnostic `shouldSatisfy` Text.isInfixOf "WARNING ACCOUNT_STATUS_NOT_ACTIVE"
    diagnostic `shouldSatisfy` Text.isInfixOf "INFO ACCOUNT_TRADING_BLOCKED_UNKNOWN"
    diagnostic `shouldSatisfy` Text.isInfixOf "INFO ACCOUNT_CRYPTO_STATUS_NOT_ACTIVE"

  it "neither data rendering nor findings accidentally introduce terminal ANSI escapes" $ do
    let (json, findings) = prepared AccountJson True limitedAccount
    json `shouldSatisfy` (not . Bytes.isInfixOf "\ESC[")
    renderAccountFindings findings `shouldSatisfy` (not . Text.isInfixOf "\ESC[")

  it "rejects invalid API payload before emitting requested data or findings" $ do
    mapM_ (\payload ->
      prepareAccountOutput (options AccountJson True) payload
        `shouldBe` Left "Invalid Alpaca account response.")
      [ "", "[]", "null", "{}", "{\"id\":\"secret\",\"status\":true}" ]

  it "treats a deliberately closed consumer pipe as a non-failure" $ do
    (readerFd, writerFd) <- createPipe
    closeFd readerFd
    writer <- fdToHandle writerFd
    delivered <- writeAccountBytes writer "expected broken pipe"
    delivered `shouldBe` False
    _ <- try (hClose writer) :: IO (Either IOException ())
    pure ()

  it "never interpolates private IDs, cash, or provider body into diagnostics" $ do
    let (_, findings) = prepared AccountJson True blockedAccount
        diagnostic = renderAccountFindings findings
    diagnostic `shouldSatisfy` (not . Text.isInfixOf "PRIVATE_ACCOUNT_ID")
    diagnostic `shouldSatisfy` (not . Text.isInfixOf "SECRET-0001")
    diagnostic `shouldSatisfy` (not . Text.isInfixOf "12.00000000000000000001")

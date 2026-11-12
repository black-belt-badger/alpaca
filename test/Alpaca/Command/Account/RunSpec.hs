{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Account.RunSpec (spec) where

import Alpaca.Command.Account.Run (renderAccountSummary, saveAccountJson)
import Alpaca.Domain.Account (Account (..))
import Control.Exception (finally)
import Data.Bits ((.&.))
import qualified Data.ByteString as ByteString
import qualified Data.Text as Text
import System.Directory (getTemporaryDirectory, removeFile)
import System.IO (hClose, openBinaryTempFile)
import System.Posix.Files (fileMode, getFileStatus, setFileMode)
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

spec :: Spec
spec = do
  it "renders the account as a readable summary" $ do
    let summary = renderAccountSummary exampleAccount
    summary `shouldSatisfy` Text.isPrefixOf "Kirke — Alpaca paper account\n"
    summary `shouldSatisfy` Text.isInfixOf "Account number: PAPER-001\n"
    summary `shouldSatisfy` Text.isInfixOf "Cash: 1234.567890123456\n"
    summary `shouldSatisfy` Text.isInfixOf "Trading blocked: no\n"
    summary `shouldSatisfy` Text.isInfixOf "Crypto status: ACTIVE\n"

  it "renders blocked trading and missing crypto status" $ do
    let summary =
          renderAccountSummary
            (exampleAccount {accountTradingBlocked = True, accountCryptoStatus = Nothing})
    summary `shouldSatisfy` Text.isInfixOf "Trading blocked: yes\n"
    summary `shouldSatisfy` Text.isInfixOf "Crypto status: not provided\n"

  it "does not include the internal account UUID" $
    renderAccountSummary exampleAccount
      `shouldSatisfy` (not . Text.isInfixOf "private-id")

  it "writes complete JSON with owner-only permissions, even when replacing a public file" $ do
    directory <- getTemporaryDirectory
    (path, handle) <- openBinaryTempFile directory "kirke-account-test-"
    hClose handle
    let json = "{\"status\":\"ACTIVE\",\"extra\":123}"
    ( do
        setFileMode path 0o644
        saveAccountJson path json
        saved <- ByteString.readFile path
        saved `shouldBe` json
        status <- getFileStatus path
        fileMode status .&. 0o777 `shouldBe` 0o600
      )
      `finally` removeFile path

exampleAccount :: Account
exampleAccount =
  Account
    { accountId = "private-id"
    , accountNumber = "PAPER-001"
    , accountStatus = "ACTIVE"
    , accountCurrency = "USD"
    , accountCash = "1234.567890123456"
    , accountEquity = "4000.00"
    , accountBuyingPower = "2500.00"
    , accountTradingBlocked = False
    , accountCryptoStatus = Just "ACTIVE"
    }

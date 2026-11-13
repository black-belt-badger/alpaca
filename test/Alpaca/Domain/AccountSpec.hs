{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.AccountSpec (spec) where

import Alpaca.Domain.Account (Account (..), AccountDetails (..), AccountStatus (..), OptionsLevel (..), optionsLevelValue, decodeAccount, statusValue)
import Data.ByteString (ByteString)
import Data.Aeson (eitherDecodeStrict', encode)
import qualified Data.ByteString.Lazy as Lazy
import qualified Data.Text as Text
import Data.Text.Encoding (encodeUtf8, decodeUtf8)
import Data.Either (isLeft)
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

spec :: Spec
spec = do
  it "decodes the account summary from Alpaca JSON" $
    case decodeAccount exampleResponse of
      Left err -> fail err
      Right account -> do
        accountId account `shouldBe` "example-id"
        accountNumber account `shouldBe` Just "PAPER-001"
        accountStatus account `shouldBe` StatusActive
        accountCurrency account `shouldBe` Just "USD"
        accountCash account `shouldBe` Just "-12.345678901234567890"
        accountEquity account `shouldBe` Just "1250.50"
        accountBuyingPower account `shouldBe` Just "2000"
        accountTradingBlocked account `shouldBe` Just False
        accountCryptoStatus account `shouldBe` Just StatusActive
        accountAccruedFees (accountDetails account) `shouldBe` Nothing

  it "decodes all documented optional account fields with their exact types" $
    case decodeAccount fullSchemaResponse of
      Left err -> fail err
      Right account -> do
        accountId account `shouldBe` "example-id"
        accountNumber account `shouldBe` Just "PAPER-001"
        accountStatus account `shouldBe` StatusActive
        accountCryptoStatus account `shouldBe` Just StatusPaperOnly
        accountCurrency account `shouldBe` Just "USD"
        accountCash account `shouldBe` Just "-12.345678901234567890123456789"
        accountEquity account `shouldBe` Just "1000.00000000000000000001"
        accountBuyingPower account `shouldBe` Just "2e0"
        accountTradingBlocked account `shouldBe` Just False
        let details = accountDetails account
        accountBlocked details `shouldBe` Just True
        accountAccruedFees details `shouldBe` Just "0.00300"
        accountBalanceAsOf details `shouldBe` Just "2026-11-12"
        accountCreatedAt details `shouldBe` Just "2026-11-11T23:59:59.123456789Z"
        accountInitialMargin details `shouldBe` Just "-0.23"
        accountIntradayAdjustments details `shouldBe` Just "100"
        accountLastEquity details `shouldBe` Just "1001"
        accountLastMaintenanceMargin details `shouldBe` Just "12.30"
        accountLongMarketValue details `shouldBe` Just "800.55"
        accountMaintenanceMargin details `shouldBe` Just "12.31"
        accountMultiplier details `shouldBe` Just "4"
        accountNonMarginableBuyingPower details `shouldBe` Just "15.35"
        accountOptionsApprovedLevel details `shouldBe` Just OptionsSpreads
        accountOptionsBuyingPower details `shouldBe` Just "45.50"
        accountOptionsTradingLevel details `shouldBe` Just OptionsLong
        accountPendingRegTafFees details `shouldBe` Just "0.00005"
        accountPendingTransferIn details `shouldBe` Just "0"
        accountPendingTransferOut details `shouldBe` Just "100.10"
        accountPortfolioValue details `shouldBe` Just "1000.00000000000000000001"
        accountRegtBuyingPower details `shouldBe` Just "200.125"
        accountShortMarketValue details `shouldBe` Just "-3.45"
        accountShortingEnabled details `shouldBe` Just True
        accountSma details `shouldBe` Just "10.00"
        accountTradeSuspendedByUser details `shouldBe` Just False
        accountTransfersBlocked details `shouldBe` Just True

  it "requires only id and status, accepting absent or null account_number" $ do
    case decodeAccount "{\"id\":\"example-id\",\"status\":\"ACTIVE\"}" of
      Left err -> fail err
      Right account -> do
        accountNumber account `shouldBe` Nothing
        accountCash account `shouldBe` Nothing
        accountTradingBlocked account `shouldBe` Nothing
        accountOptionsTradingLevel (accountDetails account) `shouldBe` Nothing
    case decodeAccount "{\"id\":\"example-id\",\"status\":\"ACTIVE\",\"account_number\":null}" of
      Left err -> fail err
      Right account -> accountNumber account `shouldBe` Nothing

  it "distinguishes missing, null, false and zero in typed optional fields" $ do
    let json = "{\"id\":\"id\",\"status\":\"ACTIVE\",\"trading_blocked\":false,\"transfers_blocked\":null,\"options_approved_level\":0,\"cash\":\"0\"}"
    case decodeAccount json of
      Left err -> fail err
      Right account -> do
        accountTradingBlocked account `shouldBe` Just False
        accountCash account `shouldBe` Just "0"
        accountEquity account `shouldBe` Nothing
        accountTransfersBlocked (accountDetails account) `shouldBe` Nothing
        accountOptionsApprovedLevel (accountDetails account) `shouldBe` Just OptionsDisabled

  it "recognizes all options-level enum values and preserves unknown integers" $ do
    let levels = [(0, OptionsDisabled), (1, OptionsCovered), (2, OptionsLong), (3, OptionsSpreads), (7, OptionsOther 7)]
    mapM_ (\(value, expected) -> do
      let json = encodeUtf8 (Text.pack (show value))
      (eitherDecodeStrict' json :: Either String OptionsLevel) `shouldBe` Right expected
      optionsLevelValue expected `shouldBe` value
      Lazy.toStrict (encode expected) `shouldBe` json
      ) levels

  it "rejects invalid types for known optional fields, not just required ones" $ do
    let baseline = "{\"id\":\"id\",\"status\":\"ACTIVE\","
        cases =
          [ "\"cash\":12.34}"
          , "\"initial_margin\":10.5}"
          , "\"trading_blocked\":\"false\"}"
          , "\"account_blocked\":0}"
          , "\"options_approved_level\":1.5}"
          , "\"options_trading_level\":\"3\"}"
          , "\"created_at\":12345}"
          , "\"crypto_status\":false}"
          ]
    mapM_ (\suffix -> decodeAccount (baseline <> suffix) `shouldSatisfy` isLeft) cases

  it "rejects non-object, missing id and missing status account payloads" $ do
    mapM_ (\payload -> decodeAccount payload `shouldSatisfy` isLeft)
      ["[]", "null", "{}", "{\"status\":\"ACTIVE\"}", "{\"id\":\"id\"}"]

  it "tolerates a missing optional crypto status" $
    case decodeAccount exampleWithoutCryptoStatus of
      Left err -> fail err
      Right account -> accountCryptoStatus account `shouldBe` Nothing

  it "decodes every documented status enum member, round-trips exact wire spelling" $ do
    let variants =
          [ ("INACTIVE", StatusInactive)
          , ("PAPER_ONLY", StatusPaperOnly)
          , ("ONBOARDING", StatusOnboarding)
          , ("SUBMITTED", StatusSubmitted)
          , ("SUBMISSION_FAILED", StatusSubmissionFailed)
          , ("ACTION_REQUIRED", StatusActionRequired)
          , ("ACCOUNT_UPDATED", StatusAccountUpdated)
          , ("APPROVAL_PENDING", StatusApprovalPending)
          , ("APPROVED", StatusApproved)
          , ("REJECTED", StatusRejected)
          , ("ACTIVE", StatusActive)
          , ("ACCOUNT_CLOSED", StatusAccountClosed)
          , ("ACCOUNT_CLOSED_PENDING", StatusAccountClosedPending)
          , ("LIMITED", StatusLimited)
          ]
    mapM_ (\(wire, constructor) -> do
      let input = encodeUtf8 ("\"" <> wire <> "\"")
      (eitherDecodeStrict' input :: Either String AccountStatus)
        `shouldBe` Right constructor
      statusValue constructor `shouldBe` wire
      Lazy.toStrict (encode constructor) `shouldBe` input
      ) variants

  it "decodes status and crypto_status independently as the same enum type" $ do
    let accountJson = Text.replace "\"crypto_status\":\"ACTIVE\""
          "\"crypto_status\":\"PAPER_ONLY\"" (decodeUtf8 exampleResponse)
        page = Text.replace "\"status\":\"ACTIVE\""
          "\"status\":\"LIMITED\"" accountJson
    case decodeAccount (encodeUtf8 page) of
      Left err -> fail err
      Right account -> do
        accountStatus account `shouldBe` StatusLimited
        accountCryptoStatus account `shouldBe` Just StatusPaperOnly

  it "retains new, unfamiliar enum values rather than rejecting the account" $ do
    let page = Text.replace "\"status\":\"ACTIVE\""
          "\"status\":\"NEW_TRADING_STATUS\"" (decodeUtf8 exampleResponse)
        both = Text.replace "\"crypto_status\":\"ACTIVE\""
          "\"crypto_status\":\"NEW_CRYPTO_STATUS\"" page
    case decodeAccount (encodeUtf8 both) of
      Left err -> fail err
      Right account -> do
        accountStatus account `shouldBe` StatusOther "NEW_TRADING_STATUS"
        accountCryptoStatus account `shouldBe` Just (StatusOther "NEW_CRYPTO_STATUS")
        statusValue (accountStatus account) `shouldBe` "NEW_TRADING_STATUS"
        Lazy.toStrict (encode (StatusOther "NEW_CRYPTO_STATUS"))
          `shouldBe` "\"NEW_CRYPTO_STATUS\""

  it "accepts null crypto_status but not a null required status" $ do
    let page = Text.replace "\"crypto_status\":\"ACTIVE\""
          "\"crypto_status\":null" (decodeUtf8 exampleResponse)
        invalid = Text.replace "\"status\":\"ACTIVE\""
          "\"status\":null" (decodeUtf8 exampleResponse)
    case decodeAccount (encodeUtf8 page) of
      Left err -> fail err
      Right account -> accountCryptoStatus account `shouldBe` Nothing
    decodeAccount (encodeUtf8 invalid) `shouldSatisfy` isLeft

  it "rejects non-string status or crypto_status instead of coercing JSON values" $ do
    let source = decodeUtf8 exampleResponse
        invalidStatus = Text.replace "\"status\":\"ACTIVE\""
          "\"status\":1" source
        invalidCrypto = Text.replace "\"crypto_status\":\"ACTIVE\""
          "\"crypto_status\":false" source
    decodeAccount (encodeUtf8 invalidStatus) `shouldSatisfy` isLeft
    decodeAccount (encodeUtf8 invalidCrypto) `shouldSatisfy` isLeft

  it "rejects malformed JSON" $
    decodeAccount "{oops" `shouldSatisfy` isLeft

  it "rejects a missing required field" $
    decodeAccount "{\"id\":\"example-id\"}" `shouldSatisfy` isLeft

  it "rejects a numeric value where the API specifies a decimal string" $
    decodeAccount exampleWithNumericCash `shouldSatisfy` isLeft

exampleResponse :: ByteString
exampleResponse =
  mconcat
    [ "{"
    , "\"id\":\"example-id\","
    , "\"account_number\":\"PAPER-001\","
    , "\"status\":\"ACTIVE\","
    , "\"currency\":\"USD\","
    , "\"cash\":\"-12.345678901234567890\","
    , "\"equity\":\"1250.50\","
    , "\"buying_power\":\"2000\","
    , "\"trading_blocked\":false,"
    , "\"crypto_status\":\"ACTIVE\","
    , "\"new_api_field\":{\"arbitrary\":true}"
    , "}"
    ]

exampleWithoutCryptoStatus :: ByteString
exampleWithoutCryptoStatus =
  mconcat
    [ "{"
    , "\"id\":\"example-id\","
    , "\"account_number\":\"PAPER-001\","
    , "\"status\":\"ACTIVE\","
    , "\"currency\":\"USD\","
    , "\"cash\":\"0\","
    , "\"equity\":\"0\","
    , "\"buying_power\":\"0\","
    , "\"trading_blocked\":true"
    , "}"
    ]

exampleWithNumericCash :: ByteString
exampleWithNumericCash =
  mconcat
    [ "{"
    , "\"id\":\"example-id\","
    , "\"account_number\":\"PAPER-001\","
    , "\"status\":\"ACTIVE\","
    , "\"currency\":\"USD\","
    , "\"cash\":12.34,"
    , "\"equity\":\"0\","
    , "\"buying_power\":\"0\","
    , "\"trading_blocked\":false"
    , "}"
    ]

fullSchemaResponse :: ByteString
fullSchemaResponse =
  mconcat
    [ "{"
    , "\"id\":\"example-id\","
    , "\"status\":\"ACTIVE\","
    , "\"crypto_status\":\"PAPER_ONLY\","
    , "\"account_number\":\"PAPER-001\","
    , "\"currency\":\"USD\","
    , "\"cash\":\"-12.345678901234567890123456789\","
    , "\"equity\":\"1000.00000000000000000001\","
    , "\"buying_power\":\"2e0\","
    , "\"trading_blocked\":false,"
    , "\"account_blocked\":true,"
    , "\"accrued_fees\":\"0.00300\","
    , "\"balance_asof\":\"2026-11-12\","
    , "\"created_at\":\"2026-11-11T23:59:59.123456789Z\","
    , "\"initial_margin\":\"-0.23\","
    , "\"intraday_adjustments\":\"100\","
    , "\"last_equity\":\"1001\","
    , "\"last_maintenance_margin\":\"12.30\","
    , "\"long_market_value\":\"800.55\","
    , "\"maintenance_margin\":\"12.31\","
    , "\"multiplier\":\"4\","
    , "\"non_marginable_buying_power\":\"15.35\","
    , "\"options_approved_level\":3,"
    , "\"options_buying_power\":\"45.50\","
    , "\"options_trading_level\":2,"
    , "\"pending_reg_taf_fees\":\"0.00005\","
    , "\"pending_transfer_in\":\"0\","
    , "\"pending_transfer_out\":\"100.10\","
    , "\"portfolio_value\":\"1000.00000000000000000001\","
    , "\"regt_buying_power\":\"200.125\","
    , "\"short_market_value\":\"-3.45\","
    , "\"shorting_enabled\":true,"
    , "\"sma\":\"10.00\","
    , "\"trade_suspended_by_user\":false,"
    , "\"transfers_blocked\":true,"
    , "\"future_new_property\":{\"pi\":\"3.1415926535897932384626\"}"
    , "}"
    ]

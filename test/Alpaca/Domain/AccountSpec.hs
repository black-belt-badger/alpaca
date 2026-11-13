{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.AccountSpec (spec) where

import Alpaca.Domain.Account (Account (..), AccountStatus (..), decodeAccount, statusValue)
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
    decodeAccount exampleResponse
      `shouldBe` Right
        ( Account
            { accountId = "example-id"
            , accountNumber = "PAPER-001"
            , accountStatus = StatusActive
            , accountCurrency = "USD"
            , accountCash = "-12.345678901234567890"
            , accountEquity = "1250.50"
            , accountBuyingPower = "2000"
            , accountTradingBlocked = False
            , accountCryptoStatus = Just StatusActive
            }
        )

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

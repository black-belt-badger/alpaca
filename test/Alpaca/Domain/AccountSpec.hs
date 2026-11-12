{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.AccountSpec (spec) where

import Alpaca.Domain.Account (Account (..), decodeAccount)
import Data.ByteString (ByteString)
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
            , accountStatus = "ACTIVE"
            , accountCurrency = "USD"
            , accountCash = "-12.345678901234567890"
            , accountEquity = "1250.50"
            , accountBuyingPower = "2000"
            , accountTradingBlocked = False
            , accountCryptoStatus = Just "ACTIVE"
            }
        )

  it "tolerates a missing optional crypto status" $
    case decodeAccount exampleWithoutCryptoStatus of
      Left err -> fail err
      Right account -> accountCryptoStatus account `shouldBe` Nothing

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

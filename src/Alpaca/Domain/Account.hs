{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.Account
  ( Account (..)
  , decodeAccount
  ) where

import Data.Aeson (FromJSON (..), eitherDecodeStrict', withObject, (.:), (.:?))
import Data.ByteString (ByteString)
import Data.Text (Text)

-- | Fields needed for a human-readable account summary.
-- The complete JSON response is retained separately for --out.
-- Alpaca sends monetary amounts as decimal strings; keep them exact.
data Account = Account
  { accountId :: Text
  , accountNumber :: Text
  , accountStatus :: Text
  , accountCurrency :: Text
  , accountCash :: Text
  , accountEquity :: Text
  , accountBuyingPower :: Text
  , accountTradingBlocked :: Bool
  , accountCryptoStatus :: Maybe Text
  }
  deriving (Eq, Show)

instance FromJSON Account where
  parseJSON = withObject "Account" $ \object ->
    Account
      <$> object .: "id"
      <*> object .: "account_number"
      <*> object .: "status"
      <*> object .: "currency"
      <*> object .: "cash"
      <*> object .: "equity"
      <*> object .: "buying_power"
      <*> object .: "trading_blocked"
      <*> object .:? "crypto_status"

-- | Decode the response without performing IO or exposing credentials.
decodeAccount :: ByteString -> Either String Account
decodeAccount = eitherDecodeStrict'

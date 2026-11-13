{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.Account
  ( Account (..)
  , AccountStatus (..)
  , statusValue
  , decodeAccount
  ) where

import Data.Aeson
  ( FromJSON (..)
  , ToJSON (..)
  , Value (String)
  , eitherDecodeStrict'
  , withObject
  , withText
  , (.:)
  , (.:?)
  )
import Data.ByteString (ByteString)
import Data.Text (Text)

-- | Known Alpaca Trading API account statuses as of June 2026.
-- Keep unfamiliar future values instead of making otherwise-valid account
-- responses unreadable when Alpaca adds a new enum member.
--
-- Both 'status' and 'crypto_status' use the same wire-level enum.
data AccountStatus
  = StatusInactive
  | StatusPaperOnly
  | StatusOnboarding
  | StatusSubmitted
  | StatusSubmissionFailed
  | StatusActionRequired
  | StatusAccountUpdated
  | StatusApprovalPending
  | StatusApproved
  | StatusRejected
  | StatusActive
  | StatusAccountClosed
  | StatusAccountClosedPending
  | StatusLimited
  | StatusOther Text
  deriving (Eq, Ord, Show)

statusValue :: AccountStatus -> Text
statusValue status = case status of
  StatusInactive -> "INACTIVE"
  StatusPaperOnly -> "PAPER_ONLY"
  StatusOnboarding -> "ONBOARDING"
  StatusSubmitted -> "SUBMITTED"
  StatusSubmissionFailed -> "SUBMISSION_FAILED"
  StatusActionRequired -> "ACTION_REQUIRED"
  StatusAccountUpdated -> "ACCOUNT_UPDATED"
  StatusApprovalPending -> "APPROVAL_PENDING"
  StatusApproved -> "APPROVED"
  StatusRejected -> "REJECTED"
  StatusActive -> "ACTIVE"
  StatusAccountClosed -> "ACCOUNT_CLOSED"
  StatusAccountClosedPending -> "ACCOUNT_CLOSED_PENDING"
  StatusLimited -> "LIMITED"
  StatusOther value -> value

instance FromJSON AccountStatus where
  parseJSON = withText "AccountStatus" $ \value ->
    pure $ case value of
      "INACTIVE" -> StatusInactive
      "PAPER_ONLY" -> StatusPaperOnly
      "ONBOARDING" -> StatusOnboarding
      "SUBMITTED" -> StatusSubmitted
      "SUBMISSION_FAILED" -> StatusSubmissionFailed
      "ACTION_REQUIRED" -> StatusActionRequired
      "ACCOUNT_UPDATED" -> StatusAccountUpdated
      "APPROVAL_PENDING" -> StatusApprovalPending
      "APPROVED" -> StatusApproved
      "REJECTED" -> StatusRejected
      "ACTIVE" -> StatusActive
      "ACCOUNT_CLOSED" -> StatusAccountClosed
      "ACCOUNT_CLOSED_PENDING" -> StatusAccountClosedPending
      "LIMITED" -> StatusLimited
      other -> StatusOther other

instance ToJSON AccountStatus where
  toJSON = String . statusValue

-- | Fields currently used for a concise account summary.
-- The complete original JSON response (including other documented and new
-- fields) is retained independently by the account command's --out export.
-- Monetary amounts remain exact decimal strings, without float conversion.
data Account = Account
  { accountId :: Text
  , accountNumber :: Text
  , accountStatus :: AccountStatus
  , accountCurrency :: Text
  , accountCash :: Text
  , accountEquity :: Text
  , accountBuyingPower :: Text
  , accountTradingBlocked :: Bool
  , accountCryptoStatus :: Maybe AccountStatus
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

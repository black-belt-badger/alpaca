{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.Account
  ( Account (..)
  , AccountStatus (..)
  , AccountDetails (..)
  , OptionsLevel (..)
  , optionsLevelValue
  , statusValue
  , decodeAccount
  ) where

import Data.Aeson
  ( FromJSON (..)
  , ToJSON (..)
  , Value (Object, String)
  , eitherDecodeStrict'
  , withObject
  , withScientific
  , withText
  , (.:)
  , (.:?)
  )
import Data.ByteString (ByteString)
import Data.Scientific (floatingOrInteger)
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

-- | Known options levels; unexpected integer levels are retained to support
-- future API changes. JSON fractional levels and string levels are invalid.
data OptionsLevel
  = OptionsDisabled
  | OptionsCovered
  | OptionsLong
  | OptionsSpreads
  | OptionsOther Integer
  deriving (Eq, Ord, Show)

optionsLevelValue :: OptionsLevel -> Integer
optionsLevelValue level = case level of
  OptionsDisabled -> 0
  OptionsCovered -> 1
  OptionsLong -> 2
  OptionsSpreads -> 3
  OptionsOther value -> value

instance FromJSON OptionsLevel where
  parseJSON = withScientific "OptionsLevel" $ \value ->
    case (floatingOrInteger value :: Either Double Integer) of
      Left _ -> fail "Options level must be an integer"
      Right number -> pure $ case number of
        0 -> OptionsDisabled
        1 -> OptionsCovered
        2 -> OptionsLong
        3 -> OptionsSpreads
        other -> OptionsOther other

instance ToJSON OptionsLevel where
  toJSON = toJSON . optionsLevelValue

-- | Additional documented GET /v2/account fields. These are all optional in
-- the current OpenAPI schema, so missing and null both map to Nothing.
-- Monetary values stay exact strings; RFC3339/date strings remain unmodified.
-- Unknown provider properties remain available via the original --out JSON.
data AccountDetails = AccountDetails
  { accountBlocked :: Maybe Bool
   ,accountAccruedFees :: Maybe Text
   ,accountBalanceAsOf :: Maybe Text
   ,accountCreatedAt :: Maybe Text
   ,accountInitialMargin :: Maybe Text
   ,accountIntradayAdjustments :: Maybe Text
   ,accountLastEquity :: Maybe Text
   ,accountLastMaintenanceMargin :: Maybe Text
   ,accountLongMarketValue :: Maybe Text
   ,accountMaintenanceMargin :: Maybe Text
   ,accountMultiplier :: Maybe Text
   ,accountNonMarginableBuyingPower :: Maybe Text
   ,accountOptionsApprovedLevel :: Maybe OptionsLevel
   ,accountOptionsBuyingPower :: Maybe Text
   ,accountOptionsTradingLevel :: Maybe OptionsLevel
   ,accountPendingRegTafFees :: Maybe Text
   ,accountPendingTransferIn :: Maybe Text
   ,accountPendingTransferOut :: Maybe Text
   ,accountPortfolioValue :: Maybe Text
   ,accountRegtBuyingPower :: Maybe Text
   ,accountShortMarketValue :: Maybe Text
   ,accountShortingEnabled :: Maybe Bool
   ,accountSma :: Maybe Text
   ,accountTradeSuspendedByUser :: Maybe Bool
   ,accountTransfersBlocked :: Maybe Bool
  }
  deriving (Eq, Show)

instance FromJSON AccountDetails where
  parseJSON = withObject "AccountDetails" $ \object ->
    AccountDetails
      <$> object .:? "account_blocked"
      <*> object .:? "accrued_fees"
      <*> object .:? "balance_asof"
      <*> object .:? "created_at"
      <*> object .:? "initial_margin"
      <*> object .:? "intraday_adjustments"
      <*> object .:? "last_equity"
      <*> object .:? "last_maintenance_margin"
      <*> object .:? "long_market_value"
      <*> object .:? "maintenance_margin"
      <*> object .:? "multiplier"
      <*> object .:? "non_marginable_buying_power"
      <*> object .:? "options_approved_level"
      <*> object .:? "options_buying_power"
      <*> object .:? "options_trading_level"
      <*> object .:? "pending_reg_taf_fees"
      <*> object .:? "pending_transfer_in"
      <*> object .:? "pending_transfer_out"
      <*> object .:? "portfolio_value"
      <*> object .:? "regt_buying_power"
      <*> object .:? "short_market_value"
      <*> object .:? "shorting_enabled"
      <*> object .:? "sma"
      <*> object .:? "trade_suspended_by_user"
      <*> object .:? "transfers_blocked"

-- | Alpaca's current account schema requires only id and status. Other
-- properties may be omitted, and account_number can explicitly be null.
-- The CLI renders "not provided" when an optional summary value is absent.
data Account = Account
  { accountId :: Text
  , accountNumber :: Maybe Text
  , accountStatus :: AccountStatus
  , accountCurrency :: Maybe Text
  , accountCash :: Maybe Text
  , accountEquity :: Maybe Text
  , accountBuyingPower :: Maybe Text
  , accountTradingBlocked :: Maybe Bool
  , accountCryptoStatus :: Maybe AccountStatus
  , accountDetails :: AccountDetails
  }
  deriving (Eq, Show)

instance FromJSON Account where
  parseJSON = withObject "Account" $ \object ->
    Account
      <$> object .: "id"
      <*> object .:? "account_number"
      <*> object .: "status"
      <*> object .:? "currency"
      <*> object .:? "cash"
      <*> object .:? "equity"
      <*> object .:? "buying_power"
      <*> object .:? "trading_blocked"
      <*> object .:? "crypto_status"
      <*> parseJSON (Object object)

-- | Decode the response without performing IO or exposing credentials.
decodeAccount :: ByteString -> Either String Account
decodeAccount = eitherDecodeStrict'

{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.Asset
  ( Asset (..)
  , AssetKind (..)
  , AssetVenue (..)
  , AssetState (..)
  , AssetAttributeValue (..)
  , BorrowStatus (..)
  , assetKindValue
  , assetVenueValue
  , assetStateValue
  , assetAttributeValue
  , borrowStatusValue
  , decodeAssets
  ) where

import Data.Aeson (FromJSON (..), ToJSON (..), Value (String), eitherDecodeStrict', withObject, withText, (.:), (.:?))
import Data.ByteString (ByteString)
import Data.Scientific (Scientific)
import Data.Text (Text)

-- | Known Alpaca enum variants use explicit constructors. A future provider
-- enum value must not make an otherwise valid asset response unreadable.
-- The raw --out JSON keeps all unknown properties without reserialization.

data AssetKind
  = KindUsEquity
  | KindUsOption
  | KindCrypto
  | KindCryptoPerp
  | KindTreasury
  | KindCorporate
  | KindGlobalEquity
  | KindUsIndex
  | KindUsEquityChain
  | KindIpo
  | KindOther Text
  deriving (Eq, Ord, Show)

assetKindValue :: AssetKind -> Text
assetKindValue value = case value of
  KindUsEquity -> "us_equity"
  KindUsOption -> "us_option"
  KindCrypto -> "crypto"
  KindCryptoPerp -> "crypto_perp"
  KindTreasury -> "treasury"
  KindCorporate -> "corporate"
  KindGlobalEquity -> "global_equity"
  KindUsIndex -> "us_index"
  KindUsEquityChain -> "us_equity_chain"
  KindIpo -> "ipo"
  KindOther other -> other

instance FromJSON AssetKind where
  parseJSON = withText "AssetKind" $ \value ->
    pure $ case value of
      "us_equity" -> KindUsEquity
      "us_option" -> KindUsOption
      "crypto" -> KindCrypto
      "crypto_perp" -> KindCryptoPerp
      "treasury" -> KindTreasury
      "corporate" -> KindCorporate
      "global_equity" -> KindGlobalEquity
      "us_index" -> KindUsIndex
      "us_equity_chain" -> KindUsEquityChain
      "ipo" -> KindIpo
      other -> KindOther other

instance ToJSON AssetKind where
  toJSON = String . assetKindValue

data AssetVenue
  = VenueAmex
  | VenueArca
  | VenueBats
  | VenueNyse
  | VenueNasdaq
  | VenueNysearca
  | VenueOtc
  | VenueCrypto
  | VenueTxse
  | VenueErsx
  | VenueCrxl
  | VenueAscx
  | VenueIndex
  | VenueNone
  | VenueOther Text
  deriving (Eq, Ord, Show)

assetVenueValue :: AssetVenue -> Text
assetVenueValue value = case value of
  VenueAmex -> "AMEX"
  VenueArca -> "ARCA"
  VenueBats -> "BATS"
  VenueNyse -> "NYSE"
  VenueNasdaq -> "NASDAQ"
  VenueNysearca -> "NYSEARCA"
  VenueOtc -> "OTC"
  VenueCrypto -> "CRYPTO"
  VenueTxse -> "TXSE"
  VenueErsx -> "ERSX"
  VenueCrxl -> "CRXL"
  VenueAscx -> "ASCX"
  VenueIndex -> "INDEX"
  VenueNone -> ""
  VenueOther other -> other

instance FromJSON AssetVenue where
  parseJSON = withText "AssetVenue" $ \value ->
    pure $ case value of
      "AMEX" -> VenueAmex
      "ARCA" -> VenueArca
      "BATS" -> VenueBats
      "NYSE" -> VenueNyse
      "NASDAQ" -> VenueNasdaq
      "NYSEARCA" -> VenueNysearca
      "OTC" -> VenueOtc
      "CRYPTO" -> VenueCrypto
      "TXSE" -> VenueTxse
      "ERSX" -> VenueErsx
      "CRXL" -> VenueCrxl
      "ASCX" -> VenueAscx
      "INDEX" -> VenueIndex
      "" -> VenueNone
      other -> VenueOther other

instance ToJSON AssetVenue where
  toJSON = String . assetVenueValue

data AssetState
  = StateActive
  | StateInactive
  | StateOther Text
  deriving (Eq, Ord, Show)

assetStateValue :: AssetState -> Text
assetStateValue value = case value of
  StateActive -> "active"
  StateInactive -> "inactive"
  StateOther other -> other

instance FromJSON AssetState where
  parseJSON = withText "AssetState" $ \value ->
    pure $ case value of
      "active" -> StateActive
      "inactive" -> StateInactive
      other -> StateOther other

instance ToJSON AssetState where
  toJSON = String . assetStateValue

data AssetAttributeValue
  = AttributePtpNoException
  | AttributePtpWithException
  | AttributeIpo
  | AttributeHasOptions
  | AttributeOptionsLateClose
  | AttributeFractionalEhEnabled
  | AttributeOvernightTradable
  | AttributeOvernightHalted
  | AttributeOther Text
  deriving (Eq, Ord, Show)

assetAttributeValue :: AssetAttributeValue -> Text
assetAttributeValue value = case value of
  AttributePtpNoException -> "ptp_no_exception"
  AttributePtpWithException -> "ptp_with_exception"
  AttributeIpo -> "ipo"
  AttributeHasOptions -> "has_options"
  AttributeOptionsLateClose -> "options_late_close"
  AttributeFractionalEhEnabled -> "fractional_eh_enabled"
  AttributeOvernightTradable -> "overnight_tradable"
  AttributeOvernightHalted -> "overnight_halted"
  AttributeOther other -> other

instance FromJSON AssetAttributeValue where
  parseJSON = withText "AssetAttributeValue" $ \value ->
    pure $ case value of
      "ptp_no_exception" -> AttributePtpNoException
      "ptp_with_exception" -> AttributePtpWithException
      "ipo" -> AttributeIpo
      "has_options" -> AttributeHasOptions
      "options_late_close" -> AttributeOptionsLateClose
      "fractional_eh_enabled" -> AttributeFractionalEhEnabled
      "overnight_tradable" -> AttributeOvernightTradable
      "overnight_halted" -> AttributeOvernightHalted
      other -> AttributeOther other

instance ToJSON AssetAttributeValue where
  toJSON = String . assetAttributeValue

data BorrowStatus
  = BorrowEasyToBorrow
  | BorrowHardToBorrow
  | BorrowOther Text
  deriving (Eq, Ord, Show)

borrowStatusValue :: BorrowStatus -> Text
borrowStatusValue value = case value of
  BorrowEasyToBorrow -> "easy_to_borrow"
  BorrowHardToBorrow -> "hard_to_borrow"
  BorrowOther other -> other

instance FromJSON BorrowStatus where
  parseJSON = withText "BorrowStatus" $ \value ->
    pure $ case value of
      "easy_to_borrow" -> BorrowEasyToBorrow
      "hard_to_borrow" -> BorrowHardToBorrow
      other -> BorrowOther other

instance ToJSON BorrowStatus where
  toJSON = String . borrowStatusValue
-- | Typed coverage of all 19 response properties in the current Alpaca
-- GET /v2/assets schema. Required properties are enforced; nullable or
-- conditional properties are optional. Numeric money/size *strings* remain
-- exact Text, while the one deprecated JSON *number* is Scientific.
data Asset = Asset
  { assetId :: Text
  , assetSymbol :: Text
  , assetName :: Text
  , assetClass :: AssetKind
  , assetExchange :: AssetVenue
  , assetStatus :: AssetState
  , assetTradable :: Bool
  , assetMarginable :: Bool
  , assetShortable :: Bool
  , assetFractionable :: Bool
  , assetAttributes :: Maybe [AssetAttributeValue]
  , assetBorrowStatus :: Maybe BorrowStatus
  , assetCusip :: Maybe Text
  , assetMaintenanceMarginRequirement :: Maybe Scientific
  , assetMarginRequirementLong :: Maybe Text
  , assetMarginRequirementShort :: Maybe Text
  , assetMinOrderSize :: Maybe Text
  , assetMinTradeIncrement :: Maybe Text
  , assetPriceIncrement :: Maybe Text
  }
  deriving (Eq, Show)

instance FromJSON Asset where
  parseJSON = withObject "Asset" $ \object ->
    Asset
      <$> object .: "id"
      <*> object .: "symbol"
      <*> object .: "name"
      <*> object .: "class"
      <*> object .: "exchange"
      <*> object .: "status"
      <*> object .: "tradable"
      <*> object .: "marginable"
      <*> object .: "shortable"
      <*> object .: "fractionable"
      <*> object .:? "attributes"
      <*> object .:? "borrow_status"
      <*> object .:? "cusip"
      <*> object .:? "maintenance_margin_requirement"
      <*> object .:? "margin_requirement_long"
      <*> object .:? "margin_requirement_short"
      <*> object .:? "min_order_size"
      <*> object .:? "min_trade_increment"
      <*> object .:? "price_increment"

-- | Alpaca returns an array, including [] for an empty match.
decodeAssets :: ByteString -> Either String [Asset]
decodeAssets = eitherDecodeStrict'

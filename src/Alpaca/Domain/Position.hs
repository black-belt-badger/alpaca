{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.Position
  ( Position (..)
  , PositionSide (..)
  , positionSideValue
  , UsdPositionValues (..)
  , decodePositions
  ) where

import Alpaca.Domain.Asset (AssetKind, AssetVenue)
import Data.Aeson (FromJSON (..), ToJSON (..), Value (String), eitherDecodeStrict', withObject, withText, (.:), (.:?))
import Data.ByteString (ByteString)
import Data.Text (Text)

-- | Alpaca's documented long/short vocabulary. Future string values remain
-- readable without changing existing paper API responses.
data PositionSide
  = SideLong
  | SideShort
  | SideOther Text
  deriving (Eq, Ord, Show)

positionSideValue :: PositionSide -> Text
positionSideValue value = case value of
  SideLong -> "long"
  SideShort -> "short"
  SideOther other -> other

instance FromJSON PositionSide where
  parseJSON = withText "PositionSide" $ \value ->
    pure $ case value of
      "long" -> SideLong
      "short" -> SideShort
      other -> SideOther other

instance ToJSON PositionSide where
  toJSON = String . positionSideValue

-- | USD-denominated values for local-currency trading positions, not the
-- same thing as the position's native-currency amounts. Only avg_entry_price
-- and cost_basis are required when the optional usd object appears.
-- Every amount and price is an exact JSON decimal string, never a Double.
data UsdPositionValues = UsdPositionValues
  { usdAvgEntryPrice :: Text
  , usdChangeToday :: Maybe Text
  , usdCostBasis :: Text
  , usdCurrentPrice :: Maybe Text
  , usdLastdayPrice :: Maybe Text
  , usdMarketValue :: Maybe Text
  , usdUnrealizedIntradayPl :: Maybe Text
  , usdUnrealizedIntradayPlpc :: Maybe Text
  , usdUnrealizedPl :: Maybe Text
  , usdUnrealizedPlpc :: Maybe Text
  }
  deriving (Eq, Show)

instance FromJSON UsdPositionValues where
  parseJSON = withObject "UsdPositionValues" $ \object ->
    UsdPositionValues
      <$> object .: "avg_entry_price"
      <*> object .:? "change_today"
      <*> object .: "cost_basis"
      <*> object .:? "current_price"
      <*> object .:? "lastday_price"
      <*> object .:? "market_value"
      <*> object .:? "unrealized_intraday_pl"
      <*> object .:? "unrealized_intraday_plpc"
      <*> object .:? "unrealized_pl"
      <*> object .:? "unrealized_plpc"

-- | All 22 published fields from GET /v2/positions. Required properties
-- are checked by decoding; absent/null optional fields are Nothing.
-- Original complete JSON (including unknown provider fields) is retained
-- without reserialization by the CLI's --out pathway.
data Position = Position
  { positionAssetClass :: AssetKind
  , positionAssetId :: Text
  , positionAssetMarginable :: Bool
  , positionAvgEntryPrice :: Text
  , positionAvgEntrySwapRate :: Maybe Text
  , positionChangeToday :: Text
  , positionCostBasis :: Text
  , positionCurrentPrice :: Text
  , positionExchange :: AssetVenue
  , positionLastdayPrice :: Text
  , positionMarketValue :: Text
  , positionPrevSwapRate :: Maybe Text
  , positionQty :: Text
  , positionQtyAvailable :: Maybe Text
  , positionSide :: PositionSide
  , positionSwapRate :: Maybe Text
  , positionSymbol :: Text
  , positionUnrealizedIntradayPl :: Text
  , positionUnrealizedIntradayPlpc :: Text
  , positionUnrealizedPl :: Text
  , positionUnrealizedPlpc :: Text
  , positionUsd :: Maybe UsdPositionValues
  }
  deriving (Eq, Show)

instance FromJSON Position where
  parseJSON = withObject "Position" $ \object ->
    Position
      <$> object .: "asset_class"
      <*> object .: "asset_id"
      <*> object .: "asset_marginable"
      <*> object .: "avg_entry_price"
      <*> object .:? "avg_entry_swap_rate"
      <*> object .: "change_today"
      <*> object .: "cost_basis"
      <*> object .: "current_price"
      <*> object .: "exchange"
      <*> object .: "lastday_price"
      <*> object .: "market_value"
      <*> object .:? "prev_swap_rate"
      <*> object .: "qty"
      <*> object .:? "qty_available"
      <*> object .: "side"
      <*> object .:? "swap_rate"
      <*> object .: "symbol"
      <*> object .: "unrealized_intraday_pl"
      <*> object .: "unrealized_intraday_plpc"
      <*> object .: "unrealized_pl"
      <*> object .: "unrealized_plpc"
      <*> object .:? "usd"

-- | Decode an array of current open positions; [] is a valid portfolio.
decodePositions :: ByteString -> Either String [Position]
decodePositions = eitherDecodeStrict'

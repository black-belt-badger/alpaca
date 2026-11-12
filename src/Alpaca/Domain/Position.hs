{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.Position
  ( Position (..)
  , decodePositions
  ) where

import Data.Aeson (FromJSON (..), eitherDecodeStrict', withObject, (.:), (.:?))
import Data.ByteString (ByteString)
import Data.Text (Text)

-- | Only the fields used by the CLI. Full provider JSON is kept separately.
-- Alpaca transmits monetary amounts and fractional quantities as strings.
data Position = Position
  { positionSymbol :: Text
  , positionAssetClass :: Text
  , positionSide :: Text
  , positionQty :: Text
  , positionMarketValue :: Maybe Text
  , positionCurrentPrice :: Maybe Text
  , positionUnrealizedPl :: Maybe Text
  }
  deriving (Eq, Show)

instance FromJSON Position where
  parseJSON = withObject "Position" $ \object ->
    Position
      <$> object .: "symbol"
      <*> object .: "asset_class"
      <*> object .: "side"
      <*> object .: "qty"
      <*> object .:? "market_value"
      <*> object .:? "current_price"
      <*> object .:? "unrealized_pl"

-- | Decode a portfolio array, including an empty portfolio.
decodePositions :: ByteString -> Either String [Position]
decodePositions = eitherDecodeStrict'

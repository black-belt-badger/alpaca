{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.Asset
  ( Asset (..)
  , decodeAssets
  ) where

import Data.Aeson (FromJSON (..), eitherDecodeStrict', withObject, (.:), (.:?))
import Data.ByteString (ByteString)
import Data.Text (Text)

-- | The stable fields needed to display each returned asset. Provider-specific
-- extras are preserved in the original JSON, not reflected in this record.
data Asset = Asset
  { assetId :: Text
  , assetSymbol :: Text
  , assetName :: Maybe Text
  , assetClass :: Text
  , assetStatus :: Text
  , assetTradable :: Bool
  , assetFractionable :: Maybe Bool
  }
  deriving (Eq, Show)

instance FromJSON Asset where
  parseJSON = withObject "Asset" $ \o ->
    Asset
      <$> o .: "id"
      <*> o .: "symbol"
      <*> o .:? "name"
      <*> o .: "class"
      <*> o .: "status"
      <*> o .: "tradable"
      <*> o .:? "fractionable"

-- | Alpaca returns an array, including [] when no assets match filters.
decodeAssets :: ByteString -> Either String [Asset]
decodeAssets = eitherDecodeStrict'

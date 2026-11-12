{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Assets
  ( AssetClass (..)
  , AssetStatus (..)
  , AssetsCommand (..)
  , assetClassParameter
  , assetStatusParameter
  , parseAssetClass
  , parseAssetStatus
  ) where

import Data.ByteString (ByteString)

-- | API query filters, distinct from the open-ended "class" in asset JSON.
data AssetClass = Crypto | UsEquity deriving (Eq, Show)

data AssetStatus = Active | Inactive | All deriving (Eq, Show)

data AssetsCommand = AssetsCommand
  { assetsClass :: AssetClass
  , assetsStatus :: Maybe AssetStatus
  , assetsOutput :: Maybe FilePath
  }
  deriving (Eq, Show)

assetClassParameter :: AssetClass -> ByteString
assetClassParameter Crypto = "crypto"
assetClassParameter UsEquity = "us_equity"

assetStatusParameter :: AssetStatus -> ByteString
assetStatusParameter Active = "active"
assetStatusParameter Inactive = "inactive"
assetStatusParameter All = "all"

parseAssetClass :: String -> Either String AssetClass
parseAssetClass "crypto" = Right Crypto
parseAssetClass "us_equity" = Right UsEquity
parseAssetClass _ = Left "Expected crypto or us_equity"

parseAssetStatus :: String -> Either String AssetStatus
parseAssetStatus "active" = Right Active
parseAssetStatus "inactive" = Right Inactive
parseAssetStatus "all" = Right All
parseAssetStatus _ = Left "Expected active, inactive, or all"

{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Assets
  ( AssetClass (..)
  , AssetStatus (..)
  , AssetExchange (..)
  , AssetAttribute (..)
  , AssetsCommand (..)
  , assetClassParameter
  , assetStatusParameter
  , assetExchangeParameter
  , assetAttributeParameter
  , parseAssetClass
  , parseAssetStatus
  , parseAssetExchanges
  , parseAssetAttributes
  , validateAssetsCommand
  ) where

import Data.ByteString (ByteString)
import Data.List (nub)
import qualified Data.Text as Text

-- | Every asset_class value in Alpaca's published AssetClass schema.
-- The CLI intentionally defaults to crypto; Alpaca's API defaults to us_equity.
data AssetClass
  = Crypto
  | UsEquity
  | UsOption
  | CryptoPerp
  | Treasury
  | Corporate
  | GlobalEquity
  | UsIndex
  | UsEquityChain
  | Ipo
  deriving (Eq, Show)

data AssetStatus = Active | Inactive | All deriving (Eq, Show)

-- | Exchange filters supported by GET /v2/assets (equity and index only).
-- Crypto venues appear in responses, but are not valid exchange filters.
data AssetExchange
  = Amex | Arca | Bats | Nyse | Nasdaq | Nysearca | Otc | Txse | Index
  deriving (Eq, Show)

data AssetAttribute
  = PtpNoException
  | PtpWithException
  | IpoAttribute
  | HasOptions
  | OptionsLateClose
  | FractionalEhEnabled
  | OvernightTradable
  | OvernightHalted
  deriving (Eq, Show)

data AssetsCommand = AssetsCommand
  { assetsClass :: AssetClass
  , assetsStatus :: Maybe AssetStatus
  , assetsExchanges :: Maybe [AssetExchange]
  , assetsAttributes :: Maybe [AssetAttribute]
  , assetsOutput :: Maybe FilePath
  }
  deriving (Eq, Show)

assetClassParameter :: AssetClass -> ByteString
assetClassParameter assetClass = case assetClass of
  Crypto -> "crypto"
  UsEquity -> "us_equity"
  UsOption -> "us_option"
  CryptoPerp -> "crypto_perp"
  Treasury -> "treasury"
  Corporate -> "corporate"
  GlobalEquity -> "global_equity"
  UsIndex -> "us_index"
  UsEquityChain -> "us_equity_chain"
  Ipo -> "ipo"

assetStatusParameter :: AssetStatus -> ByteString
assetStatusParameter Active = "active"
assetStatusParameter Inactive = "inactive"
assetStatusParameter All = "all"

assetExchangeParameter :: AssetExchange -> ByteString
assetExchangeParameter exchange = case exchange of
  Amex -> "AMEX"
  Arca -> "ARCA"
  Bats -> "BATS"
  Nyse -> "NYSE"
  Nasdaq -> "NASDAQ"
  Nysearca -> "NYSEARCA"
  Otc -> "OTC"
  Txse -> "TXSE"
  Index -> "INDEX"

assetAttributeParameter :: AssetAttribute -> ByteString
assetAttributeParameter attribute = case attribute of
  PtpNoException -> "ptp_no_exception"
  PtpWithException -> "ptp_with_exception"
  IpoAttribute -> "ipo"
  HasOptions -> "has_options"
  OptionsLateClose -> "options_late_close"
  FractionalEhEnabled -> "fractional_eh_enabled"
  OvernightTradable -> "overnight_tradable"
  OvernightHalted -> "overnight_halted"

parseAssetClass :: String -> Either String AssetClass
parseAssetClass value = case value of
  "crypto" -> Right Crypto
  "us_equity" -> Right UsEquity
  "us_option" -> Right UsOption
  "crypto_perp" -> Right CryptoPerp
  "treasury" -> Right Treasury
  "corporate" -> Right Corporate
  "global_equity" -> Right GlobalEquity
  "us_index" -> Right UsIndex
  "us_equity_chain" -> Right UsEquityChain
  "ipo" -> Right Ipo
  _ -> Left "Expected a documented asset_class: crypto, us_equity, us_option, crypto_perp, treasury, corporate, global_equity, us_index, us_equity_chain, ipo"

parseAssetStatus :: String -> Either String AssetStatus
parseAssetStatus "active" = Right Active
parseAssetStatus "inactive" = Right Inactive
parseAssetStatus "all" = Right All
parseAssetStatus _ = Left "Expected active, inactive, or all"

parseAssetExchanges :: String -> Either String [AssetExchange]
parseAssetExchanges = parseCsv "exchanges" parseExchange

parseExchange :: String -> Either String AssetExchange
parseExchange value = case value of
  "AMEX" -> Right Amex
  "ARCA" -> Right Arca
  "BATS" -> Right Bats
  "NYSE" -> Right Nyse
  "NASDAQ" -> Right Nasdaq
  "NYSEARCA" -> Right Nysearca
  "OTC" -> Right Otc
  "TXSE" -> Right Txse
  "INDEX" -> Right Index
  _ -> Left "Expected exchange AMEX, ARCA, BATS, NYSE, NASDAQ, NYSEARCA, OTC, TXSE, or INDEX"

parseAssetAttributes :: String -> Either String [AssetAttribute]
parseAssetAttributes = parseCsv "attributes" parseAttribute

parseAttribute :: String -> Either String AssetAttribute
parseAttribute value = case value of
  "ptp_no_exception" -> Right PtpNoException
  "ptp_with_exception" -> Right PtpWithException
  "ipo" -> Right IpoAttribute
  "has_options" -> Right HasOptions
  "options_late_close" -> Right OptionsLateClose
  "fractional_eh_enabled" -> Right FractionalEhEnabled
  "overnight_tradable" -> Right OvernightTradable
  "overnight_halted" -> Right OvernightHalted
  _ -> Left "Unknown asset attribute; expected a documented attribute value"

-- | No silent filtering of empty, duplicate or unknown CSV tokens.
parseCsv :: Eq a => String -> (String -> Either String a) -> String -> Either String [a]
parseCsv label parseOne input = do
  let parts = map (Text.unpack . Text.strip) (Text.splitOn "," (Text.pack input))
  if any null parts
    then Left ("Expected nonempty comma-separated " <> label)
    else do
      values <- traverse parseOne parts
      if length values == length (nub values)
        then Right values
        else Left ("Duplicate " <> label <> " are not allowed")

-- | Validate related options before credentials are loaded or IO occurs.
-- Exchange filters apply only to US equities and US indexes. INDEX is an
-- artificial index exchange and must be paired with asset_class=us_index.
validateAssetsCommand :: AssetsCommand -> Either String AssetsCommand
validateAssetsCommand options
  | assetsAttributes options == Just [] =
      Left "Attribute filter must contain at least one attribute"
  | otherwise =
      case assetsExchanges options of
        Nothing -> Right options
        Just exchanges
          | null exchanges -> Left "Exchange filter must contain at least one exchange"
          | assetsClass options == UsEquity && Index `elem` exchanges ->
              Left "INDEX exchange requires --asset-class us_index"
          | assetsClass options == UsEquity -> Right options
          | assetsClass options == UsIndex && all (== Index) exchanges -> Right options
          | assetsClass options == UsIndex ->
              Left "us_index assets can only be filtered by exchange INDEX"
          | otherwise ->
              Left "Exchange filtering is available only for us_equity or us_index"

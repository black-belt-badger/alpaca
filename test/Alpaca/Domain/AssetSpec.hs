{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.AssetSpec (spec) where

import Alpaca.Domain.Asset
  ( Asset (..), AssetKind (..), AssetState (..), AssetVenue (..)
  , AssetAttributeValue (..), BorrowStatus (..), decodeAssets)
import Data.Aeson (Value (..), fromJSON, toJSON, Result (..), encode, eitherDecodeStrict')
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString.Lazy as Lazy
import Data.ByteString (ByteString)
import qualified Data.Text as Text
import Data.Text.Encoding (decodeUtf8, encodeUtf8)
import Data.Either (isLeft)
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

spec :: Spec
spec = do
  it "decodes crypto and equity assets with required fields" $
    case decodeAssets sample of
      Left err -> fail err
      Right [crypto, equity] -> do
        assetId crypto `shouldBe` "crypto-uuid"
        assetSymbol crypto `shouldBe` "BTC/USD"
        assetName crypto `shouldBe` "Bitcoin"
        assetClass crypto `shouldBe` KindCrypto
        assetExchange crypto `shouldBe` VenueCrypto
        assetStatus crypto `shouldBe` StateActive
        assetTradable crypto `shouldBe` True
        assetMarginable crypto `shouldBe` False
        assetShortable crypto `shouldBe` False
        assetFractionable crypto `shouldBe` True
        assetStatus equity `shouldBe` StateInactive
        assetClass equity `shouldBe` KindUsEquity
        assetExchange equity `shouldBe` VenueNasdaq
        assetTradable equity `shouldBe` False
      Right _ -> fail "Expected two assets"

  it "decodes all 19 documented asset response properties" $
    case decodeAssets fullResponse of
      Left err -> fail err
      Right [asset] -> do
        assetId asset `shouldBe` "example-uuid"
        assetClass asset `shouldBe` KindUsEquity
        assetExchange asset `shouldBe` VenueNasdaq
        assetSymbol asset `shouldBe` "AAPL"
        assetName asset `shouldBe` "Apple Inc."
        assetStatus asset `shouldBe` StateActive
        assetTradable asset `shouldBe` True
        assetMarginable asset `shouldBe` True
        assetShortable asset `shouldBe` True
        assetFractionable asset `shouldBe` True
        assetAttributes asset `shouldBe` Just [AttributeHasOptions, AttributeOvernightTradable]
        assetBorrowStatus asset `shouldBe` Just BorrowEasyToBorrow
        assetCusip asset `shouldBe` Nothing
        assetMaintenanceMarginRequirement asset `shouldBe` Just (read "0.3075")
        assetMarginRequirementLong asset `shouldBe` Just "0.305000000000000001"
        assetMarginRequirementShort asset `shouldBe` Just "1.3000"
        assetMinOrderSize asset `shouldBe` Just "0.0000000000000000000000001"
        assetMinTradeIncrement asset `shouldBe` Just "0.000000000001"
        assetPriceIncrement asset `shouldBe` Just "0.00005"
      Right _ -> fail "Expected one asset"

  it "preserves future enum members while keeping known values typed" $ do
    let input = "[{\"id\":\"id\",\"symbol\":\"X\",\"name\":\"Future\",\"class\":\"new_asset_class\",\"exchange\":\"MOON\",\"status\":\"halted\",\"tradable\":false,\"marginable\":false,\"shortable\":false,\"fractionable\":false,\"attributes\":[\"has_options\",\"new_attribute\"],\"borrow_status\":\"not_available\"}]"
    case decodeAssets input of
      Left err -> fail err
      Right [asset] -> do
        assetClass asset `shouldBe` KindOther "new_asset_class"
        assetExchange asset `shouldBe` VenueOther "MOON"
        assetStatus asset `shouldBe` StateOther "halted"
        assetAttributes asset `shouldBe` Just [AttributeHasOptions, AttributeOther "new_attribute"]
        assetBorrowStatus asset `shouldBe` Just (BorrowOther "not_available")
      Right _ -> fail "Expected one asset"

  it "round trips known and future enum wire values without normalization" $ do
    let values =
          [ (String "us_equity", KindUsEquity)
          , (String "crypto_perp", KindCryptoPerp)
          , (String "global_equity", KindGlobalEquity)
          , (String "us_index", KindUsIndex)
          , (String "new_kind", KindOther "new_kind")
          ]
    mapM_ (\(wire, parsed) -> do
      fromJSON wire `shouldBe` Success parsed
      toJSON parsed `shouldBe` wire
      ) values
    toJSON VenueAscx `shouldBe` String "ASCX"
    toJSON VenueCrxl `shouldBe` String "CRXL"
    toJSON StateInactive `shouldBe` String "inactive"
    toJSON AttributeOvernightHalted `shouldBe` String "overnight_halted"
    toJSON BorrowHardToBorrow `shouldBe` String "hard_to_borrow"
    (eitherDecodeStrict' "true" :: Either String AssetState) `shouldSatisfy` isLeft
    (eitherDecodeStrict' "123" :: Either String AssetVenue) `shouldSatisfy` isLeft

  it "accepts explicit null conditional metadata" $ do
    let nulls = Text.replace "\"fractionable\":true"
          "\"fractionable\":true,\"attributes\":null,\"borrow_status\":null,\"margin_requirement_long\":null"
          (decodeUtf8 minimalResponse)
    case decodeAssets (encodeUtf8 nulls) of
      Left err -> fail err
      Right [asset] -> do
        assetAttributes asset `shouldBe` Nothing
        assetBorrowStatus asset `shouldBe` Nothing
        assetMarginRequirementLong asset `shouldBe` Nothing
      Right _ -> fail "Expected one asset"

  it "rejects missing required fields and invalid types for all conditional shapes" $ do
    let invalidRequired = [ "id", "symbol", "name", "class", "exchange", "status"
                          , "tradable", "marginable", "shortable", "fractionable" ]
    mapM_ (\key -> do
      let trimmed = KeyMap.delete (Key.fromString key) requiredObject
      decodeAssets (Lazy.toStrict (encode [Object trimmed])) `shouldSatisfy` isLeft
      ) invalidRequired
    let wrong =
          [ ("name", Number 3)
          , ("exchange", Bool True)
          , ("status", Number 2)
          , ("attributes", String "has_options")
          , ("borrow_status", Bool True)
          , ("cusip", Number 5)
          , ("maintenance_margin_requirement", String "0.35")
          , ("margin_requirement_long", Number 1)
          , ("min_order_size", Number 0)
          , ("price_increment", Bool False)
          , ("shortable", String "false")
          ]
    mapM_ (\(key, val) -> do
      let modified = KeyMap.insert (Key.fromString key) val requiredObject
      decodeAssets (Lazy.toStrict (encode [Object modified])) `shouldSatisfy` isLeft
      ) wrong

  it "accepts no matching assets" $
    decodeAssets "[]" `shouldBe` Right []

  it "accepts optional fields omitted or null" $
    case decodeAssets minimalResponse of
      Left err -> fail err
      Right [asset] -> do
        assetAttributes asset `shouldBe` Nothing
        assetBorrowStatus asset `shouldBe` Nothing
        assetCusip asset `shouldBe` Nothing
        assetMinOrderSize asset `shouldBe` Nothing
      Right _ -> fail "Expected one asset"

  it "rejects a single object when an array is expected" $
    decodeAssets "{\"symbol\":\"BTC/USD\"}" `shouldSatisfy` isLeft

  it "rejects malformed JSON" $
    decodeAssets "[bad]" `shouldSatisfy` isLeft

  it "rejects absent required fields" $
    decodeAssets "[{\"symbol\":\"BTC/USD\"}]" `shouldSatisfy` isLeft

  it "rejects non-boolean tradability" $
    decodeAssets "[{\"id\":\"id\",\"symbol\":\"BTC/USD\",\"class\":\"crypto\",\"status\":\"active\",\"tradable\":\"yes\"}]" `shouldSatisfy` isLeft

  it "does not confuse asset class with the query parameter name" $
    decodeAssets "[{\"id\":\"id\",\"symbol\":\"BTC/USD\",\"asset_class\":\"crypto\",\"status\":\"active\",\"tradable\":true}]" `shouldSatisfy` isLeft

minimalResponse :: ByteString
minimalResponse =
  "[{\"id\":\"id\",\"symbol\":\"SOL/USD\",\"name\":\"Solana\",\"class\":\"crypto\",\"exchange\":\"CRYPTO\",\"status\":\"active\",\"tradable\":true,\"marginable\":false,\"shortable\":false,\"fractionable\":true}]"

sample :: ByteString
sample =
  mconcat
    [ "["
    , "{\"id\":\"crypto-uuid\",\"symbol\":\"BTC/USD\",\"name\":\"Bitcoin\","
    , "\"class\":\"crypto\",\"exchange\":\"CRYPTO\",\"status\":\"active\",\"tradable\":true,"
    , "\"marginable\":false,\"shortable\":false,\"fractionable\":true,"
    , "\"extra\":{\"will\":\"be ignored\"}},"
    , "{\"id\":\"equity-uuid\",\"symbol\":\"AAPL\",\"name\":\"Apple Inc.\","
    , "\"class\":\"us_equity\",\"exchange\":\"NASDAQ\",\"status\":\"inactive\",\"tradable\":false,"
    , "\"marginable\":true,\"shortable\":true,\"fractionable\":false}"
    , "]"
    ]

fullResponse :: ByteString
fullResponse = "[{\"id\":\"example-uuid\",\"class\":\"us_equity\",\"exchange\":\"NASDAQ\",\"symbol\":\"AAPL\",\"name\":\"Apple Inc.\",\"status\":\"active\",\"tradable\":true,\"marginable\":true,\"shortable\":true,\"fractionable\":true,\"attributes\":[\"has_options\",\"overnight_tradable\"],\"borrow_status\":\"easy_to_borrow\",\"cusip\":null,\"maintenance_margin_requirement\":0.3075,\"margin_requirement_long\":\"0.305000000000000001\",\"margin_requirement_short\":\"1.3000\",\"min_order_size\":\"0.0000000000000000000000001\",\"min_trade_increment\":\"0.000000000001\",\"price_increment\":\"0.00005\",\"new_field\":{\"counter\":\"12345678901234567890\"}}]"

requiredObject :: KeyMap.KeyMap Value
requiredObject =
  case eitherDecodeStrict' minimalResponse of
    Right [Object object] -> object
    _ -> error "Invalid required test asset fixture"

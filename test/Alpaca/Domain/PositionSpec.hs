{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Domain.PositionSpec (spec) where

import Alpaca.Domain.Asset (AssetKind (..), AssetVenue (..))
import Alpaca.Domain.Position (Position (..), PositionSide (..), UsdPositionValues (..), decodePositions, positionSideValue)
import Data.Aeson (Value (..), object, encode, toJSON, fromJSON, Result (..), (.=))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as Lazy
import Data.Either (isLeft)
import Data.Text (Text)
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

spec :: Spec
spec = do
  it "decodes crypto and equity positions with every required field" $
    case decodePositions sampleResponse of
      Left err -> fail err
      Right [crypto, equity] -> do
        positionSymbol crypto `shouldBe` "BTCUSD"
        positionAssetId crypto `shouldBe` "00000000-0000-0000-0000-000000000001"
        positionAssetClass crypto `shouldBe` KindCrypto
        positionExchange crypto `shouldBe` VenueCrypto
        positionSide crypto `shouldBe` SideLong
        positionQty crypto `shouldBe` "0.000997498123456789012345"
        positionMarketValue crypto `shouldBe` "67.123456789012345"
        positionCurrentPrice crypto `shouldBe` "67291.12"
        positionUnrealizedPl crypto `shouldBe` "-0.000000000001"
        positionAssetMarginable crypto `shouldBe` False
        positionSymbol equity `shouldBe` "AAPL"
        positionAssetClass equity `shouldBe` KindUsEquity
        positionExchange equity `shouldBe` VenueNasdaq
        positionSide equity `shouldBe` SideShort
        positionMarketValue equity `shouldBe` "-400.50"
        positionAssetMarginable equity `shouldBe` True
      Right _ -> fail "Expected two sample positions"

  it "covers every documented field including long decimal strings and swap rates" $
    case decodePositions (asArray fullPosition) of
      Left err -> fail err
      Right [position] -> do
        positionAvgEntryPrice position `shouldBe` "67123.0000000000000000000001"
        positionAvgEntrySwapRate position `shouldBe` Just "1.00000000000000000001"
        positionChangeToday position `shouldBe` "-0.00000000001"
        positionCostBasis position `shouldBe` "68.00123456789012345678"
        positionCurrentPrice position `shouldBe` "67291.12"
        positionLastdayPrice position `shouldBe` "66500.50"
        positionMarketValue position `shouldBe` "67.123456789012345"
        positionPrevSwapRate position `shouldBe` Just "0.99999999999999999998"
        positionQty position `shouldBe` "0.000997498123456789012345"
        positionQtyAvailable position `shouldBe` Just "0.0009"
        positionSide position `shouldBe` SideLong
        positionSwapRate position `shouldBe` Just "0.99999999999999999999"
        positionUnrealizedIntradayPl position `shouldBe` "-1.00000000000000009"
        positionUnrealizedIntradayPlpc position `shouldBe` "-0.0001"
        positionUnrealizedPl position `shouldBe` "-0.000000000001"
        positionUnrealizedPlpc position `shouldBe` "-0.0000000000123456789"
        positionAssetMarginable position `shouldBe` False
      Right _ -> fail "Expected one full position"

  it "decodes optional nested USD position values with exact string precision" $
    case decodePositions (asArray fullPosition) of
      Left err -> fail err
      Right [position] -> case positionUsd position of
        Nothing -> fail "Expected nested USD position values"
        Just usd -> do
          usdAvgEntryPrice usd `shouldBe` "67000.000000000000000001"
          usdChangeToday usd `shouldBe` Just "-0.123456789"
          usdCostBasis usd `shouldBe` "100.00"
          usdCurrentPrice usd `shouldBe` Just "67123.41"
          usdLastdayPrice usd `shouldBe` Just "67120.00"
          usdMarketValue usd `shouldBe` Just "99.9999999999999999999"
          usdUnrealizedIntradayPl usd `shouldBe` Just "-0.001"
          usdUnrealizedIntradayPlpc usd `shouldBe` Just "-0.00001"
          usdUnrealizedPl usd `shouldBe` Just "-0.2"
          usdUnrealizedPlpc usd `shouldBe` Just "-0.002"
      Right _ -> fail "Expected one position"

  it "accepts optional properties missing and explicitly null, without conflating zero" $ do
    case decodePositions (asArray samplePosition) of
      Left err -> fail err
      Right [position] -> do
        positionQtyAvailable position `shouldBe` Nothing
        positionSwapRate position `shouldBe` Nothing
        positionUsd position `shouldBe` Nothing
        positionAvgEntrySwapRate position `shouldBe` Nothing
      Right _ -> fail "Expected one position"
    let withNulls = insertFields
          [ ("qty_available", Null), ("swap_rate", Null)
          , ("avg_entry_swap_rate", Null), ("usd", Null)
          , ("prev_swap_rate", Null)
          ] samplePosition
    case decodePositions (asArray withNulls) of
      Left err -> fail err
      Right [position] -> do
        positionQtyAvailable position `shouldBe` Nothing
        positionUsd position `shouldBe` Nothing
      Right _ -> fail "Expected one position"
    let withZero = insertFields [("qty_available", String "0"), ("swap_rate", String "0")] samplePosition
    case decodePositions (asArray withZero) of
      Left err -> fail err
      Right [position] -> do
        positionQtyAvailable position `shouldBe` Just "0"
        positionSwapRate position `shouldBe` Just "0"
      Right _ -> fail "Expected one position"

  it "allows documented blank exchange for positions with no exchange" $ do
    let optionPosition = insertFields [("asset_class", String "us_option"), ("exchange", String "")] samplePosition
    case decodePositions (asArray optionPosition) of
      Left err -> fail err
      Right [position] -> do
        positionExchange position `shouldBe` VenueNone
        positionAssetClass position `shouldBe` KindUsOption
      Right _ -> fail "Expected one position"

  it "preserves future asset classes, venues and side strings" $ do
    let upcoming = insertFields
          [ ("asset_class", String "future_class"), ("exchange", String "FUTURE"),
            ("side", String "new_side") ] samplePosition
    case decodePositions (asArray upcoming) of
      Left err -> fail err
      Right [position] -> do
        positionAssetClass position `shouldBe` KindOther "future_class"
        positionExchange position `shouldBe` VenueOther "FUTURE"
        positionSide position `shouldBe` SideOther "new_side"
      Right _ -> fail "Expected one position"

  it "round trips known and unknown position side enum strings" $ do
    forValues
      [ ("long", SideLong), ("short", SideShort), ("pending_future", SideOther "pending_future") ]

  it "returns [] for a portfolio without open positions" $
    decodePositions "[]" `shouldBe` Right []

  it "rejects missing or null for each of the 17 required properties" $ do
    let requiredKeys =
          [ "asset_class", "asset_id", "asset_marginable", "avg_entry_price",
            "change_today", "cost_basis", "current_price", "exchange",
            "lastday_price", "market_value", "qty", "side", "symbol",
            "unrealized_intraday_pl", "unrealized_intraday_plpc",
            "unrealized_pl", "unrealized_plpc" ]
    mapM_ (\key -> do
      let missing = deleteField key samplePosition
      decodePositions (asArray missing) `shouldSatisfy` isLeft
      let nullValue = insertFields [(key, Null)] samplePosition
      decodePositions (asArray nullValue) `shouldSatisfy` isLeft
      ) requiredKeys

  it "rejects incorrect types for required and optional properties" $ do
    let wrong =
          [ ("asset_class", Number 1)
          , ("exchange", Bool False)
          , ("asset_marginable", String "false")
          , ("side", Bool True)
          , ("qty", Number 0.125)
          , ("market_value", Number 10.50)
          , ("current_price", Bool True)
          , ("avg_entry_price", Number 9)
          , ("cost_basis", Number 1)
          , ("qty_available", Number 0)
          , ("swap_rate", Number 1)
          , ("avg_entry_swap_rate", Bool True)
          , ("usd", String "not an object")
          ]
    mapM_ (\(key, value) ->
      decodePositions (asArray (insertFields [(key, value)] samplePosition)) `shouldSatisfy` isLeft
      ) wrong

  it "rejects missing USD required fields and incorrect USD value types" $ do
    mapM_ (\usd ->
      decodePositions (asArray (insertFields [("usd", usd)] samplePosition)) `shouldSatisfy` isLeft
      ) [ object ["cost_basis" .= String "12.00"]
        , object ["avg_entry_price" .= String "100.00"]
        , object ["avg_entry_price" .= String "100.00", "cost_basis" .= Number 12]
        , object ["avg_entry_price" .= String "100.00", "cost_basis" .= String "12.00", "market_value" .= Number 10]
        ]

  it "accepts minimal valid USD object with two required values" $ do
    let nested = object ["avg_entry_price" .= String "42.00", "cost_basis" .= String "100.00"]
    case decodePositions (asArray (insertFields [("usd", nested)] samplePosition)) of
      Left err -> fail err
      Right [position] -> case positionUsd position of
        Nothing -> fail "Missing nested values"
        Just usd -> do
          usdAvgEntryPrice usd `shouldBe` "42.00"
          usdCostBasis usd `shouldBe` "100.00"
          usdMarketValue usd `shouldBe` Nothing
      Right _ -> fail "Expected one position"

  it "rejects malformed JSON and a single object instead of an array" $ do
    decodePositions "[oops" `shouldSatisfy` isLeft
    decodePositions (Lazy.toStrict (encode samplePosition)) `shouldSatisfy` isLeft

-- All fixtures are deliberately synthetic, not snapshots of private accounts.
samplePosition :: Value
samplePosition =
  object
    [ "asset_class" .= String "crypto"
    , "asset_id" .= String "00000000-0000-0000-0000-000000000001"
    , "asset_marginable" .= Bool False
    , "avg_entry_price" .= String "67123.0000000000000000000001"
    , "change_today" .= String "-0.00000000001"
    , "cost_basis" .= String "68.00123456789012345678"
    , "current_price" .= String "67291.12"
    , "exchange" .= String "CRYPTO"
    , "lastday_price" .= String "66500.50"
    , "market_value" .= String "67.123456789012345"
    , "qty" .= String "0.000997498123456789012345"
    , "side" .= String "long"
    , "symbol" .= String "BTCUSD"
    , "unrealized_intraday_pl" .= String "-1.00000000000000009"
    , "unrealized_intraday_plpc" .= String "-0.0001"
    , "unrealized_pl" .= String "-0.000000000001"
    , "unrealized_plpc" .= String "-0.0000000000123456789"
    , "provider_future_field" .= object ["new" .= String "3.1415926535897932384626"]
    ]

equityPosition :: Value
equityPosition = insertFields
  [ ("asset_class", String "us_equity"), ("exchange", String "NASDAQ")
  , ("symbol", String "AAPL"), ("side", String "short"),
    ("market_value", String "-400.50"), ("asset_marginable", Bool True)
  ] samplePosition

fullPosition :: Value
fullPosition =
  insertFields
    [ ("avg_entry_swap_rate", String "1.00000000000000000001")
    , ("prev_swap_rate", String "0.99999999999999999998")
    , ("qty_available", String "0.0009")
    , ("swap_rate", String "0.99999999999999999999")
    , ("usd", object
        [ "avg_entry_price" .= String "67000.000000000000000001"
        , "change_today" .= String "-0.123456789"
        , "cost_basis" .= String "100.00"
        , "current_price" .= String "67123.41"
        , "lastday_price" .= String "67120.00"
        , "market_value" .= String "99.9999999999999999999"
        , "unrealized_intraday_pl" .= String "-0.001"
        , "unrealized_intraday_plpc" .= String "-0.00001"
        , "unrealized_pl" .= String "-0.2"
        , "unrealized_plpc" .= String "-0.002"
        ])
    ]
    samplePosition

sampleResponse :: ByteString
sampleResponse = Lazy.toStrict (encode [samplePosition, equityPosition])

asArray :: Value -> ByteString
asArray one = Lazy.toStrict (encode [one])

deleteField :: String -> Value -> Value
deleteField key (Object obj) = Object (KeyMap.delete (Key.fromString key) obj)
deleteField _ value = value

insertFields :: [(String, Value)] -> Value -> Value
insertFields pairs (Object obj) =
  Object (foldr (\(name, value) acc -> KeyMap.insert (Key.fromString name) value acc) obj pairs)
insertFields _ value = value

forValues :: [(Text, PositionSide)] -> IO ()
forValues values =
  mapM_ (\(wire, expected) -> do
    let parsed = fromJSON (String wire)
    parsed `shouldBe` Success expected
    positionSideValue expected `shouldBe` wire
    toJSON expected `shouldBe` String wire
    ) values

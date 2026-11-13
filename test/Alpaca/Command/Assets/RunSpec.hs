{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Assets.RunSpec (spec) where

import Alpaca.Command.Assets.Run (renderAssetsSummary)
import Alpaca.Domain.Asset (Asset, decodeAssets)
import Data.ByteString (ByteString)
import qualified Data.Text as Text
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

spec :: Spec
spec = do
  it "describes zero matching assets" $
    renderAssetsSummary [] `shouldBe` "Kirke — Alpaca paper assets\nNo matching assets.\n"

  it "renders useful metadata and human-readable booleans" $ do
    let summary = renderAssetsSummary [crypto, equity]
    summary `shouldSatisfy` Text.isPrefixOf "Kirke — Alpaca paper assets\nAssets: 2\n"
    summary `shouldSatisfy` Text.isInfixOf "BTC/USD (crypto, active)\n"
    summary `shouldSatisfy` Text.isInfixOf "  Name: Bitcoin\n"
    summary `shouldSatisfy` Text.isInfixOf "  Tradable: yes\n"
    summary `shouldSatisfy` Text.isInfixOf "  Fractionable: yes\n"
    summary `shouldSatisfy` Text.isInfixOf "AAPL (us_equity, inactive)\n"
    summary `shouldSatisfy` Text.isInfixOf "  Tradable: no\n"

  it "does not display the internal asset UUID" $
    renderAssetsSummary [crypto]
      `shouldSatisfy` (not . Text.isInfixOf "crypto-uuid")

crypto :: Asset
crypto = fixture "{\"id\":\"crypto-uuid\",\"symbol\":\"BTC/USD\",\"name\":\"Bitcoin\",\"class\":\"crypto\",\"exchange\":\"CRYPTO\",\"status\":\"active\",\"tradable\":true,\"marginable\":false,\"shortable\":false,\"fractionable\":true}"

equity :: Asset
equity = fixture "{\"id\":\"equity-uuid\",\"symbol\":\"AAPL\",\"name\":\"Apple Inc.\",\"class\":\"us_equity\",\"exchange\":\"NASDAQ\",\"status\":\"inactive\",\"tradable\":false,\"marginable\":true,\"shortable\":false,\"fractionable\":false}"

fixture :: ByteString -> Asset
fixture json =
  case decodeAssets ("[" <> json <> "]") of
    Right [asset] -> asset
    _ -> error "Invalid static asset test fixture"

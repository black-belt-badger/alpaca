{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Assets.RunSpec (spec) where

import Alpaca.Command.Assets.Run (renderAssetsSummary)
import Alpaca.Domain.Asset (Asset (..))
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

  it "handles absent optional metadata" $
    renderAssetsSummary [crypto {assetName = Nothing, assetFractionable = Nothing}]
      `shouldSatisfy` Text.isInfixOf "  Fractionable: not provided\n"

  it "does not display the internal asset UUID" $
    renderAssetsSummary [crypto]
      `shouldSatisfy` (not . Text.isInfixOf "crypto-uuid")

crypto :: Asset
crypto = Asset "crypto-uuid" "BTC/USD" (Just "Bitcoin") "crypto" "active" True (Just True)

equity :: Asset
equity = Asset "equity-uuid" "AAPL" (Just "Apple Inc.") "us_equity" "inactive" False (Just False)

{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.AssetsSpec (spec) where

import Alpaca.Command.Assets
  ( AssetClass (..)
  , AssetStatus (..)
  , AssetsCommand (..)
  , assetClassParameter
  , assetStatusParameter
  , parseAssetClass
  , parseAssetStatus
  )
import Test.Hspec (Spec, it, shouldBe)

spec :: Spec
spec = do
  it "uses an explicit crypto query value" $
    assetClassParameter Crypto `shouldBe` "crypto"

  it "encodes the alternate asset class" $
    assetClassParameter UsEquity `shouldBe` "us_equity"

  it "encodes status filters" $ do
    assetStatusParameter Active `shouldBe` "active"
    assetStatusParameter Inactive `shouldBe` "inactive"
    assetStatusParameter All `shouldBe` "all"

  it "validates asset classes before sending HTTP requests" $ do
    parseAssetClass "crypto" `shouldBe` Right Crypto
    parseAssetClass "us_equity" `shouldBe` Right UsEquity
    parseAssetClass "???"
      `shouldBe` Left "Expected crypto or us_equity"

  it "validates status filters" $ do
    parseAssetStatus "active" `shouldBe` Right Active
    parseAssetStatus "inactive" `shouldBe` Right Inactive
    parseAssetStatus "all" `shouldBe` Right All
    parseAssetStatus "disabled"
      `shouldBe` Left "Expected active, inactive, or all"

  it "retains the output option in the typed command" $
    assetsOutput (AssetsCommand Crypto Nothing (Just "assets.json"))
      `shouldBe` Just "assets.json"

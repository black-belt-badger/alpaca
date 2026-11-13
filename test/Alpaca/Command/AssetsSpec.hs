{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.AssetsSpec (spec) where

import Alpaca.Command.Assets
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
  )
import Data.Either (isLeft)
import qualified Data.ByteString.Char8 as Char8
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

spec :: Spec
spec = do
  it "accepts and serializes all ten documented asset classes" $ do
    let classes =
          [ ("us_equity", UsEquity)
          , ("us_option", UsOption)
          , ("crypto", Crypto)
          , ("crypto_perp", CryptoPerp)
          , ("treasury", Treasury)
          , ("corporate", Corporate)
          , ("global_equity", GlobalEquity)
          , ("us_index", UsIndex)
          , ("us_equity_chain", UsEquityChain)
          , ("ipo", Ipo)
          ]
    mapM_ (\(wire, assetClass) -> do
      parseAssetClass wire `shouldBe` Right assetClass
      assetClassParameter assetClass `shouldBe` Char8.pack wire
      ) classes
    parseAssetClass "options" `shouldSatisfy` isLeft
    parseAssetClass "CRYPTO" `shouldSatisfy` isLeft

  it "encodes documented asset statuses" $ do
    parseAssetStatus "active" `shouldBe` Right Active
    parseAssetStatus "inactive" `shouldBe` Right Inactive
    parseAssetStatus "all" `shouldBe` Right All
    assetStatusParameter Active `shouldBe` "active"
    assetStatusParameter Inactive `shouldBe` "inactive"
    assetStatusParameter All `shouldBe` "all"
    parseAssetStatus "disabled" `shouldSatisfy` isLeft

  it "accepts and serializes the nine exchange filter values" $ do
    let exchanges =
          [ ("AMEX", Amex), ("ARCA", Arca), ("BATS", Bats)
          , ("NYSE", Nyse), ("NASDAQ", Nasdaq), ("NYSEARCA", Nysearca)
          , ("OTC", Otc), ("TXSE", Txse), ("INDEX", Index)
          ]
    mapM_ (\(wire, exchange) -> do
      parseAssetExchanges wire `shouldBe` Right [exchange]
      assetExchangeParameter exchange `shouldBe` Char8.pack wire
      ) exchanges

  it "accepts and serializes all eight documented asset attributes" $ do
    let attributes =
          [ ("ptp_no_exception", PtpNoException)
          , ("ptp_with_exception", PtpWithException)
          , ("ipo", IpoAttribute)
          , ("has_options", HasOptions)
          , ("options_late_close", OptionsLateClose)
          , ("fractional_eh_enabled", FractionalEhEnabled)
          , ("overnight_tradable", OvernightTradable)
          , ("overnight_halted", OvernightHalted)
          ]
    mapM_ (\(wire, attribute) -> do
      parseAssetAttributes wire `shouldBe` Right [attribute]
      assetAttributeParameter attribute `shouldBe` Char8.pack wire
      ) attributes

  it "supports comma-separated exchanges and attributes with spaces" $ do
    parseAssetExchanges "NASDAQ, NYSE,TXSE" `shouldBe` Right [Nasdaq, Nyse, Txse]
    parseAssetAttributes "has_options, overnight_tradable"
      `shouldBe` Right [HasOptions, OvernightTradable]

  it "rejects empty, repeated, unknown or malformed CSV filters" $ do
    mapM_ (\input -> parseAssetExchanges input `shouldSatisfy` isLeft)
      ["", ",", "NASDAQ,", ",NASDAQ", "NASDAQ,,NYSE", "NASDAQ,NASDAQ", "NASDAQ,NYSE@", "crypto", "CRYPTO"]
    mapM_ (\input -> parseAssetAttributes input `shouldSatisfy` isLeft)
      ["", ",", "ipo,", ",ipo", "ipo,,has_options", "ipo,ipo", "IPO", "new_attribute"]

  it "checks equity exchange restrictions before loading credentials" $ do
    validateAssetsCommand (args UsEquity (Just [Nasdaq, Nyse])) `shouldBe`
      Right (args UsEquity (Just [Nasdaq, Nyse]))
    validateAssetsCommand (args UsIndex (Just [Index])) `shouldBe`
      Right (args UsIndex (Just [Index]))
    validateAssetsCommand (args UsEquity (Just [Index])) `shouldSatisfy` isLeft
    validateAssetsCommand (args UsIndex (Just [Nasdaq])) `shouldSatisfy` isLeft
    validateAssetsCommand (args Crypto (Just [Nasdaq])) `shouldSatisfy` isLeft
    validateAssetsCommand (args CryptoPerp (Just [Index])) `shouldSatisfy` isLeft
    validateAssetsCommand (args UsOption (Just [Nyse])) `shouldSatisfy` isLeft
    validateAssetsCommand (args UsEquity (Just [])) `shouldSatisfy` isLeft
    validateAssetsCommand (args Crypto Nothing) `shouldBe` Right (args Crypto Nothing)
    validateAssetsCommand ((args Crypto Nothing) { assetsAttributes = Just [] }) `shouldSatisfy` isLeft

  it "retains output and both filters in the typed command" $ do
    let options = (args UsEquity (Just [Nasdaq]))
          { assetsAttributes = Just [HasOptions, IpoAttribute]
          , assetsStatus = Just Active
          , assetsOutput = Just "assets.json"
          }
    assetsOutput options `shouldBe` Just "assets.json"
    assetsStatus options `shouldBe` Just Active
    assetsAttributes options `shouldBe` Just [HasOptions, IpoAttribute]

args :: AssetClass -> Maybe [AssetExchange] -> AssetsCommand
args assetClass exchanges =
  AssetsCommand assetClass Nothing exchanges Nothing Nothing

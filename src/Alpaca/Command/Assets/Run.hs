{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Assets.Run
  ( runAssets
  , renderAssetsSummary
  ) where

import Alpaca.Client (alpacaErrorMessage, fetchAssets)
import Alpaca.Command.Assets (AssetsCommand (..), validateAssetsCommand)
import Alpaca.Credentials (credentialErrorMessage, loadCredentials)
import Alpaca.Domain.Asset (Asset (..), assetKindValue, assetStateValue, decodeAssets)
import Alpaca.Output (savePrivateJson)
import Control.Exception (IOException, displayException, try)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import System.Exit (die)

runAssets :: AssetsCommand -> IO ()
runAssets uncheckedOptions = do
  options <- either die pure (validateAssetsCommand uncheckedOptions)
  credentials <- loadCredentials >>= either (die . credentialErrorMessage) pure
  response <- fetchAssets credentials options
    >>= either (die . alpacaErrorMessage) pure
  assets <- either (die . ("Invalid Alpaca assets response: " <>)) pure (decodeAssets response)
  case assetsOutput options of
    Nothing -> TextIO.putStr (renderAssetsSummary assets)
    Just path -> do
      result <- try (savePrivateJson path response) :: IO (Either IOException ())
      case result of
        Left err -> die ("Could not save assets JSON: " <> displayException err)
        Right () -> putStrLn ("Saved complete assets JSON to " <> path)

renderAssetsSummary :: [Asset] -> Text
renderAssetsSummary assets =
  Text.unlines $
    ["Kirke — Alpaca paper assets"] <>
      if null assets
        then ["No matching assets."]
        else
          ("Assets: " <> Text.pack (show (length assets))) :
          concatMap renderAsset assets

renderAsset :: Asset -> [Text]
renderAsset asset =
  [ assetSymbol asset <> " (" <> assetKindValue (assetClass asset) <> ", " <> assetStateValue (assetStatus asset) <> ")"
  , "  Name: " <> assetName asset
  , "  Tradable: " <> boolText (assetTradable asset)
  , "  Fractionable: " <> boolText (assetFractionable asset)
  ]
  where
    boolText True = "yes"
    boolText False = "no"

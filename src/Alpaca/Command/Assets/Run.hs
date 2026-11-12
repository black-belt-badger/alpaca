{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Assets.Run
  ( runAssets
  , renderAssetsSummary
  ) where

import Alpaca.Client (alpacaErrorMessage, fetchAssets)
import Alpaca.Command.Assets (AssetsCommand (..))
import Alpaca.Credentials (credentialErrorMessage, loadCredentials)
import Alpaca.Domain.Asset (Asset (..), decodeAssets)
import Alpaca.Output (savePrivateJson)
import Control.Exception (IOException, displayException, try)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import System.Exit (die)

runAssets :: AssetsCommand -> IO ()
runAssets options = do
  credentials <- loadCredentials >>= either (die . credentialErrorMessage) pure
  response <- fetchAssets credentials (assetsClass options) (assetsStatus options)
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
  [ assetSymbol asset <> " (" <> assetClass asset <> ", " <> assetStatus asset <> ")"
  , "  Name: " <> maybe "not provided" id (assetName asset)
  , "  Tradable: " <> boolText (assetTradable asset)
  , "  Fractionable: " <> maybe "not provided" boolText (assetFractionable asset)
  ]
  where
    boolText True = "yes"
    boolText False = "no"

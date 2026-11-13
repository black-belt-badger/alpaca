{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Positions.Run
  ( runPositions
  , renderPositionsSummary
  ) where

import Alpaca.Client (alpacaErrorMessage, fetchPositions)
import Alpaca.Command.Positions (PositionsCommand (..))
import Alpaca.Credentials (credentialErrorMessage, loadCredentials)
import Alpaca.Domain.Asset (assetKindValue)
import Alpaca.Domain.Position (Position (..), decodePositions, positionSideValue)
import Alpaca.Output (savePrivateJson)
import Control.Exception (IOException, displayException, try)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import System.Exit (die)

runPositions :: PositionsCommand -> IO ()
runPositions options = do
  credentials <- loadCredentials >>= either (die . credentialErrorMessage) pure
  response <- fetchPositions credentials >>= either (die . alpacaErrorMessage) pure
  positions <- either (die . ("Invalid Alpaca positions response: " <>)) pure (decodePositions response)
  case positionsOutput options of
    Nothing -> TextIO.putStr (renderPositionsSummary positions)
    Just path -> do
      result <- try (savePrivateJson path response) :: IO (Either IOException ())
      case result of
        Left err -> die ("Could not save positions JSON: " <> displayException err)
        Right () -> putStrLn ("Saved complete positions JSON to " <> path)

renderPositionsSummary :: [Position] -> Text
renderPositionsSummary positions =
  Text.unlines $
    ["Kirke — Alpaca paper positions"] <>
      if null positions
        then ["No open positions."]
        else
          ("Positions: " <> Text.pack (show (length positions))) :
          concatMap renderPosition positions

renderPosition :: Position -> [Text]
renderPosition position =
  [ positionSymbol position <> " (" <> assetKindValue (positionAssetClass position) <> ", " <> positionSideValue (positionSide position) <> ")"
  , "  Quantity: " <> positionQty position
  , "  Market value: " <> positionMarketValue position
  , "  Current price: " <> positionCurrentPrice position
  , "  Unrealized P/L: " <> positionUnrealizedPl position
  ]

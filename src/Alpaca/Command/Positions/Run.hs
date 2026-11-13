{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Positions.Run
  ( runPositions
  , renderPositionsSummary
  , presentPositions
  ) where

import Alpaca.Client (alpacaErrorMessage, fetchPositions)
import Alpaca.Command.Positions (PositionsCommand (..))
import Alpaca.Credentials (credentialErrorMessage, loadCredentials)
import Alpaca.Domain.Asset (assetKindValue)
import Alpaca.Domain.Position (Position (..), decodePositions, positionSideValue)
import Alpaca.Output (savePrivateJson)
import Control.Exception (IOException, displayException, try)
import Data.ByteString (ByteString)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import System.Exit (die)

runPositions :: PositionsCommand -> IO ()
runPositions options = do
  credentials <- loadCredentials >>= either (die . credentialErrorMessage) pure
  response <- fetchPositions credentials >>= either (die . alpacaErrorMessage) pure
  outcome <- presentPositions (positionsOutput options) response
  either die TextIO.putStr outcome

-- | Validate complete provider data before writing to stdout or a private file.
-- Reuse this boundary in offline tests without credentials or network calls.
presentPositions :: Maybe FilePath -> ByteString -> IO (Either String Text)
presentPositions target response =
  case decodePositions response of
    Left _ -> pure (Left "Invalid Alpaca positions response.")
    Right positions -> case target of
      Nothing -> pure (Right (renderPositionsSummary positions))
      Just path -> do
        result <- try (savePrivateJson path response) :: IO (Either IOException ())
        pure $ case result of
          Left err -> Left ("Could not save positions JSON: " <> displayException err)
          Right () -> Right ("Saved complete positions JSON to " <> Text.pack path <> "\n")

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

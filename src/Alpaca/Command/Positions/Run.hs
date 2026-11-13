{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Positions.Run
  ( runPositions
  , renderPositionsSummary
  , presentPositions
  , preparePositionsOutput
  ) where

import Alpaca.Client (alpacaErrorMessage, fetchPositions)
import Alpaca.Cli.Output (renderCliFindings, writeCliBytes)
import Alpaca.Command.Positions (PositionsCommand (..), PositionsFormat (..))
import Alpaca.Credentials (credentialErrorMessage, loadCredentials)
import Alpaca.Diagnostics (Finding)
import Alpaca.Diagnostics.Positions (positionsFindings)
import Alpaca.Domain.Asset (assetKindValue)
import Alpaca.Domain.Position (Position (..), decodePositions, positionSideValue)
import Alpaca.Output (savePrivateJson)
import Control.Exception (IOException, displayException, try)
import Control.Monad (when)
import Data.ByteString (ByteString)
import qualified Data.Text.Encoding as Encoding
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import System.Exit (die)
import System.IO (stderr, stdout)

runPositions :: PositionsCommand -> IO ()
runPositions options = do
  credentials <- loadCredentials >>= either (die . credentialErrorMessage) pure
  response <- fetchPositions credentials >>= either (die . alpacaErrorMessage) pure
  (payload, findings) <- either die pure (preparePositionsOutput options response)
  delivered <- case positionsOutput options of
    Nothing -> writeCliBytes stdout payload
    Just path -> do
      result <- try (savePrivateJson path response) :: IO (Either IOException ())
      case result of
        Left err -> die ("Could not save positions JSON: " <> displayException err)
        Right () -> writeCliBytes stdout
          (Encoding.encodeUtf8 ("Saved complete positions JSON to " <> Text.pack path <> "\n"))
  when (delivered && positionsCheck options) $
    TextIO.hPutStr stderr (renderCliFindings findings)

-- | Read-only presentation boundary: validation precedes any output or file.
preparePositionsOutput :: PositionsCommand -> ByteString -> Either String (ByteString, [Finding])
preparePositionsOutput options response = do
  positions <- either (const (Left "Invalid Alpaca positions response.")) Right (decodePositions response)
  let payload = case positionsFormat options of
        PositionsText -> Encoding.encodeUtf8 (renderPositionsSummary positions)
        PositionsJson -> response
      findings = if positionsCheck options then positionsFindings positions else []
  Right (payload, findings)

-- | Existing API remains available, preserving output and private file semantics.
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

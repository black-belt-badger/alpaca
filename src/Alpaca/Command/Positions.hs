module Alpaca.Command.Positions
  ( PositionsCommand (..)
  , PositionsFormat (..)
  , parsePositionsFormat
  ) where

data PositionsFormat = PositionsText | PositionsJson
  deriving (Eq, Show)

parsePositionsFormat :: String -> Either String PositionsFormat
parsePositionsFormat "text" = Right PositionsText
parsePositionsFormat "json" = Right PositionsJson
parsePositionsFormat _ = Left "Positions format must be text or json"

data PositionsCommand = PositionsCommand
  { positionsOutput :: Maybe FilePath
  , positionsFormat :: PositionsFormat
  , positionsCheck :: Bool
  }
  deriving (Eq, Show)

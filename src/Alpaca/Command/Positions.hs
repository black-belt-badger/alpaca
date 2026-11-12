module Alpaca.Command.Positions (PositionsCommand (..)) where

data PositionsCommand = PositionsCommand
  { positionsOutput :: Maybe FilePath
  }
  deriving (Eq, Show)

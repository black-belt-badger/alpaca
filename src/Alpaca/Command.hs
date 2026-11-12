module Alpaca.Command (Command (..)) where

import Alpaca.Command.Account (AccountCommand)
import Alpaca.Command.Positions (PositionsCommand)

-- | Supported subcommands of the @kirke@ CLI.
data Command
  = Account AccountCommand
  | Positions PositionsCommand
  deriving (Eq, Show)

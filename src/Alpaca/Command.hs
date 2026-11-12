module Alpaca.Command (Command (..)) where

import Alpaca.Command.Account (AccountCommand)

-- | Supported subcommands of the @alpaca@ CLI.
data Command
  = Account AccountCommand
  deriving (Eq, Show)

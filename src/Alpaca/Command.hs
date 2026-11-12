module Alpaca.Command (Command (..)) where

import Alpaca.Command.Account (AccountCommand)

-- | Supported subcommands of the @kirke@ CLI.
data Command
  = Account AccountCommand
  deriving (Eq, Show)

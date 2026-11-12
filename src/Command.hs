module Command (Command (..)) where

import AccountCommand (AccountCommand)

-- | Supported subcommands of the @alpaca@ CLI.
data Command
  = Account AccountCommand
  deriving (Eq, Show)

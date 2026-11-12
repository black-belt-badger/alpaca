module Alpaca.Command.Account (AccountCommand (..)) where

-- | Options for the @kirke account@ subcommand.
data AccountCommand = AccountCommand
  { accountOutput :: Maybe FilePath
  }
  deriving (Eq, Show)

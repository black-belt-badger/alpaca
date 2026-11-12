module AccountCommand (AccountCommand (..)) where

-- | Options for the @alpaca account@ subcommand.
data AccountCommand = AccountCommand
  { accountOutput :: Maybe FilePath
  }
  deriving (Eq, Show)

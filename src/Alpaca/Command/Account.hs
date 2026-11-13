module Alpaca.Command.Account
  ( AccountCommand (..)
  , AccountFormat (..)
  , parseAccountFormat
  ) where

-- | Account output mode; JSON is the original, validated provider document.
data AccountFormat = AccountText | AccountJson
  deriving (Eq, Show)

parseAccountFormat :: String -> Either String AccountFormat
parseAccountFormat "text" = Right AccountText
parseAccountFormat "json" = Right AccountJson
parseAccountFormat _ = Left "Account format must be text or json"

-- | Options for the @kirke account@ subcommand. Legacy --out stays unchanged.
data AccountCommand = AccountCommand
  { accountOutput :: Maybe FilePath
  , accountFormat :: AccountFormat
  , accountCheck :: Bool
  }
  deriving (Eq, Show)

module Alpaca.Command (Command (..)) where

import Alpaca.Command.Account (AccountCommand)
import Alpaca.Command.Assets (AssetsCommand)
import Alpaca.Command.Orders (OrdersCommand)
import Alpaca.Command.Positions (PositionsCommand)

-- | Supported subcommands of the @kirke@ CLI.
data Command
  = Account AccountCommand
  | Positions PositionsCommand
  | Assets AssetsCommand
  | Orders OrdersCommand
  deriving (Eq, Show)

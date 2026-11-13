module Alpaca.Command (Command (..)) where

import Alpaca.Command.Account (AccountCommand)
import Alpaca.Command.Assets (AssetsCommand)
import Alpaca.Command.Crypto.Bars (CryptoBarsCommand)
import Alpaca.Command.Crypto.Trades (CryptoTradesCommand)
import Alpaca.Command.Crypto.Quotes (CryptoQuotesCommand)
import Alpaca.Command.Order (OrderCommand)
import Alpaca.Command.Orders (OrdersCommand)
import Alpaca.Command.Positions (PositionsCommand)

-- | Supported subcommands of the @kirke@ CLI.
data Command
  = Account AccountCommand
  | Positions PositionsCommand
  | Assets AssetsCommand
  | Orders OrdersCommand
  | Order OrderCommand
  | CryptoBars CryptoBarsCommand
  | CryptoTrades CryptoTradesCommand
  | CryptoQuotes CryptoQuotesCommand
  deriving (Eq, Show)

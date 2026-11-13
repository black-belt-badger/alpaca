module Main (main) where

import Alpaca.Command (Command (..))
import Alpaca.Command.Account.Run (runAccount)
import Alpaca.Command.Assets.Run (runAssets)
import Alpaca.Command.Crypto.Bars.Run (runCryptoBars)
import Alpaca.Command.Crypto.Trades.Run (runCryptoTrades)
import Alpaca.Command.Order.Run (runOrder)
import Alpaca.Command.Orders.Run (runOrders)
import Alpaca.Command.Positions.Run (runPositions)
import Alpaca.Command.Parser (commandParserInfo)
import Options.Applicative (execParser)

main :: IO ()
main = do
  command <- execParser commandParserInfo
  case command of
    Account options -> runAccount options
    Positions options -> runPositions options
    Assets options -> runAssets options
    Orders options -> runOrders options
    Order options -> runOrder options
    CryptoBars options -> runCryptoBars options
    CryptoTrades options -> runCryptoTrades options

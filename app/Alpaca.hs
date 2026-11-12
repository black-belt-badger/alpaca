module Main (main) where

import Alpaca.Command (Command (..))
import Alpaca.Command.Account.Run (runAccount)
import Alpaca.Command.Parser (commandParserInfo)
import Options.Applicative (execParser)

main :: IO ()
main = do
  command <- execParser commandParserInfo
  case command of
    Account options -> runAccount options

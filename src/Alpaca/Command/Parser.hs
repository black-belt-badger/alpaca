module Alpaca.Command.Parser (commandParserInfo) where

import Alpaca.Command.Account (AccountCommand (..))
import Alpaca.Command (Command (..))
import Alpaca.Command.Positions (PositionsCommand (..))
import Options.Applicative
  ( Parser
  , ParserInfo
  , command
  , fullDesc
  , help
  , helper
  , hsubparser
  , info
  , long
  , metavar
  , optional
  , progDesc
  , strOption
  , (<**>)
  )

commandParserInfo :: ParserInfo Command
commandParserInfo =
  info (commandParser <**> helper)
    (fullDesc <> progDesc "Kirke: Alpaca paper trading CLI")

commandParser :: Parser Command
commandParser =
  hsubparser
    ( command "account"
        ( info (Account <$> accountParser)
            (progDesc "Fetch Alpaca account information")
        )
        <> command "positions"
          (info (Positions <$> positionsParser)
            (progDesc "List Alpaca paper account open positions"))
    )

accountParser :: Parser AccountCommand
accountParser = AccountCommand <$> outputParser

positionsParser :: Parser PositionsCommand
positionsParser = PositionsCommand <$> outputParser

outputParser :: Parser (Maybe FilePath)
outputParser =
  optional
    ( strOption
        ( long "out"
            <> metavar "PATH"
            <> help "Write the complete JSON response to PATH"
        )
    )

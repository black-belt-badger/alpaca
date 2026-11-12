module CommandParser (commandParserInfo) where

import AccountCommand (AccountCommand (..))
import Command (Command (..))
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
    (fullDesc <> progDesc "Alpaca command-line client")

commandParser :: Parser Command
commandParser =
  hsubparser
    ( command "account"
        ( info (Account <$> accountParser)
            (progDesc "Fetch Alpaca account information")
        )
    )

accountParser :: Parser AccountCommand
accountParser =
  AccountCommand
    <$> optional
      ( strOption
          ( long "out"
              <> metavar "PATH"
              <> help "Write the complete JSON response to PATH"
          )
      )

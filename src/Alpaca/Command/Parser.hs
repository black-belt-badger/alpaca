module Alpaca.Command.Parser (commandParserInfo) where

import Alpaca.Command.Account (AccountCommand (..))
import Alpaca.Command.Assets
  ( AssetClass (Crypto)
  , AssetsCommand (..)
  , parseAssetClass
  , parseAssetStatus
  )
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
  , option
  , eitherReader
  , value
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
        <> command "assets"
          (info (Assets <$> assetsParser)
            (progDesc "List Alpaca paper assets (crypto by default)"))
    )

accountParser :: Parser AccountCommand
accountParser = AccountCommand <$> outputParser

positionsParser :: Parser PositionsCommand
positionsParser = PositionsCommand <$> outputParser

assetsParser :: Parser AssetsCommand
assetsParser =
  AssetsCommand
    <$> option (eitherReader parseAssetClass)
      ( long "asset-class"
          <> metavar "CLASS"
          <> value Crypto
          <> help "Asset class: crypto (default), us_equity"
      )
    <*> optional
      ( option (eitherReader parseAssetStatus)
          ( long "status"
              <> metavar "STATUS"
              <> help "Filter by active, inactive, or all (default: no filter)"
          )
      )
    <*> outputParser

outputParser :: Parser (Maybe FilePath)
outputParser =
  optional
    ( strOption
        ( long "out"
            <> metavar "PATH"
            <> help "Write the complete JSON response to PATH"
        )
    )

module Alpaca.Command.Parser (commandParserInfo) where

import Alpaca.Command.Account (AccountCommand (..))
import Alpaca.Command.Assets
  ( AssetClass (Crypto)
  , AssetsCommand (..)
  , parseAssetClass
  , parseAssetStatus
  )
import Alpaca.Command (Command (..))
import Alpaca.Command.Orders
  ( OrdersCommand (..)
  , OrderFilter (OpenOrders)
  , OrderDirection (Descending)
  , parseOrderFilter
  , parseOrderDirection
  , parseOrderLimit
  , parseOrderSymbol
  )
import Alpaca.Command.Positions (PositionsCommand (..))
import Options.Applicative
  ( Parser
  , many
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
        <> command "orders"
          (info (Orders <$> ordersParser)
            (progDesc "List Alpaca paper orders (read-only)"))
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

ordersParser :: Parser OrdersCommand
ordersParser =
  OrdersCommand
    <$> option (eitherReader parseOrderFilter)
      ( long "status"
          <> metavar "STATUS"
          <> value OpenOrders
          <> help "Orders to list: open (default), closed, all"
      )
    <*> optional
      (option (eitherReader parseOrderLimit)
        ( long "limit"
            <> metavar "N"
            <> help "Maximum orders (1-500; API default 50)"
        ))
    <*> many
      (option (eitherReader parseOrderSymbol)
        ( long "symbol"
            <> metavar "SYMBOL"
            <> help "Filter symbol; repeat for several (e.g. BTCUSD)"
        ))
    <*> option (eitherReader parseOrderDirection)
      ( long "direction"
          <> metavar "DIR"
          <> value Descending
          <> help "Sort order: desc (default), asc"
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

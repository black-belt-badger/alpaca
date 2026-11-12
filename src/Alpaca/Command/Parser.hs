module Alpaca.Command.Parser (commandParserInfo) where

import Alpaca.Command.Account (AccountCommand (..))
import Alpaca.Command.Assets
  ( AssetClass (Crypto)
  , AssetsCommand (..)
  , parseAssetClass
  , parseAssetStatus
  )
import Alpaca.Command (Command (..))
import Alpaca.Command.Order (OrderCommand (..), OrderGetCommand (..), parseOrderId)
import Alpaca.Command.Orders (OrderDirection (Desc), OrderStatus (OrdersOpen), OrdersCommand (..), parseOrderStatus, parseOrderDirection, parseOrderLimit, parseOrderSymbols)
import Alpaca.Command.Positions (PositionsCommand (..))
import Options.Applicative
  ( Parser
  , argument
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
  , switch
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
            (progDesc "List and filter Alpaca paper orders (read-only)"))
        <> command "order"
          (info (Order <$> orderParser)
            (progDesc "Inspect an individual Alpaca paper order"))
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

orderParser :: Parser OrderCommand
orderParser =
  hsubparser
    (command "get"
      (info (GetOrder <$> orderGetParser)
        (progDesc "Fetch a single Alpaca paper order by UUID")))

orderGetParser :: Parser OrderGetCommand
orderGetParser =
  OrderGetCommand
    <$> argument (eitherReader parseOrderId)
      (metavar "ORDER_ID" <> help "Alpaca server order UUID")
    <*> switch
      (long "nested" <> help "Roll up multi-leg orders under the parent order (API query nested=true)")
    <*> outputParser

ordersParser :: Parser OrdersCommand
ordersParser =
  OrdersCommand
    <$> option (eitherReader parseOrderStatus)
      (long "status" <> metavar "STATUS" <> value OrdersOpen <> help "open (default), closed, or all")
    <*> optional (option (eitherReader parseOrderLimit)
      (long "limit" <> metavar "N" <> help "Maximum orders, between 1 and 500 (default: 50)"))
    <*> optional (option (eitherReader parseOrderSymbols)
      (long "symbols" <> metavar "SYMBOLS" <> help "Comma-separated symbols, e.g. BTCUSD,ETHUSD,AAPL"))
    <*> option (eitherReader parseOrderDirection)
      (long "direction" <> metavar "DIRECTION" <> value Desc <> help "asc or desc (default)")
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

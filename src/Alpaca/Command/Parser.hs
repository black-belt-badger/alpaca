module Alpaca.Command.Parser (commandParserInfo) where

import Alpaca.Command.Account (AccountCommand (..))
import Alpaca.Command.Crypto.Trades (CryptoTradesCommand (..))
import Alpaca.Command.Crypto.Quotes (CryptoQuotesCommand (..))
import Alpaca.Command.Crypto.Bars
  ( BarsFormat (BarsJson)
  , BarsSort (BarsAsc)
  , CryptoBarsCommand (..)
  , CryptoLocation (Us)
  , parseBarsFormat
  , parseInstant
  , parseLocation
  , parseMaxPages
  , parsePageLimit
  , parsePageToken
  , parseSort
  , parseSymbols
  , parseTimeframe
  )
import Alpaca.Command.Assets
  ( AssetClass (Crypto)
  , AssetsCommand (..)
  , parseAssetClass
  , parseAssetStatus
  , parseAssetExchanges
  , parseAssetAttributes
  )
import Alpaca.Command (Command (..))
import Alpaca.Command.Order
  ( OrderCommand (..), OrderGetCommand (..), OrderCancelCommand (..), parseOrderId )
import Alpaca.Command.Order.Submit
  ( SubmitCommand (..), SubmitTimeInForce (SubmitGtc)
  , parseSubmitSymbol, parseSubmitAmount, parseClientOrderId
  , parseSubmitSide, parseSubmitKind, parseSubmitTimeInForce )
import Alpaca.Command.Orders
  ( OrderDirection (Desc), OrderStatus (OrdersOpen), OrdersCommand (..)
  , parseOrderStatus, parseOrderDirection, parseOrderLimit, parseOrderSymbols
  , parseOrderSide, parseOrderAssetClasses, parseOrderTimestamp
  )
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
        <> command "crypto"
          (info cryptoParser
            (progDesc "Read historical crypto market data"))
    )

cryptoParser :: Parser Command
cryptoParser =
  hsubparser
    (command "bars"
      (info (CryptoBars <$> cryptoBarsParser)
        (progDesc "Fetch bounded historical crypto OHLCV bars"))
      <> command "trades"
        (info (CryptoTrades <$> cryptoTradesParser)
          (progDesc "Fetch bounded historical crypto trades"))
      <> command "quotes"
        (info (CryptoQuotes <$> cryptoQuotesParser)
          (progDesc "Fetch bounded historical crypto best bid/ask quotes")))

cryptoBarsParser :: Parser CryptoBarsCommand
cryptoBarsParser =
  CryptoBarsCommand
    <$> option (eitherReader parseSymbols)
      (long "symbols" <> metavar "PAIRS" <> help "Required: BTC/USD,ETH/USD,SOL/USD")
    <*> option (eitherReader parseLocation)
      (long "location" <> metavar "LOCATION" <> value Us <> help "us (default), us-1, us-2, eu-1, bs-1")
    <*> option (eitherReader parseTimeframe)
      (long "timeframe" <> metavar "TIMEFRAME" <> help "Required: e.g. 1Min, 5Min, 1Hour, 1Day")
    <*> optional (option (eitherReader parseInstant)
      (long "start" <> metavar "RFC3339" <> help "Inclusive start date or timestamp"))
    <*> optional (option (eitherReader parseInstant)
      (long "end" <> metavar "RFC3339" <> help "Inclusive end date or timestamp"))
    <*> option (eitherReader parsePageLimit)
      (long "limit" <> metavar "N" <> value 1000 <> help "Bars per page, 1..10000 (default: 1000 across all symbols)")
    <*> option (eitherReader parseSort)
      (long "sort" <> metavar "SORT" <> value BarsAsc <> help "asc (default) or desc")
    <*> option (eitherReader parseMaxPages)
      (long "max-pages" <> metavar "N" <> value 1 <> help "Maximum pages, 1..20 (default: 1)")
    <*> optional (option (eitherReader parsePageToken)
      (long "page-token" <> metavar "TOKEN" <> help "Resume from previous API pagination token"))
    <*> option (eitherReader parseBarsFormat)
      (long "format" <> metavar "FORMAT" <> value BarsJson <> help "json (default) or jsonl" )
    <*> optional
      (strOption (long "out" <> metavar "PATH" <> help "Save JSON page envelopes or JSONL bar records privately"))

cryptoTradesParser :: Parser CryptoTradesCommand
cryptoTradesParser =
  CryptoTradesCommand
    <$> option (eitherReader parseSymbols)
      (long "symbols" <> metavar "PAIRS" <> help "Required: BTC/USD,ETH/USD,SOL/USD")
    <*> option (eitherReader parseLocation)
      (long "location" <> metavar "LOCATION" <> value Us <> help "us (default), us-1, us-2, eu-1, bs-1")
    <*> optional (option (eitherReader parseInstant)
      (long "start" <> metavar "RFC3339" <> help "Inclusive start date or timestamp"))
    <*> optional (option (eitherReader parseInstant)
      (long "end" <> metavar "RFC3339" <> help "Inclusive end date or timestamp"))
    <*> option (eitherReader parsePageLimit)
      (long "limit" <> metavar "N" <> value 1000 <> help "Trades per page, 1..10000 (default: 1000 across symbols)")
    <*> option (eitherReader parseSort)
      (long "sort" <> metavar "SORT" <> value BarsAsc <> help "asc (default) or desc")
    <*> option (eitherReader parseMaxPages)
      (long "max-pages" <> metavar "N" <> value 1 <> help "Maximum pages, 1..20 (default: 1)")
    <*> optional (option (eitherReader parsePageToken)
      (long "page-token" <> metavar "TOKEN" <> help "Resume from previous API pagination token"))
    <*> option (eitherReader parseBarsFormat)
      (long "format" <> metavar "FORMAT" <> value BarsJson <> help "json (default) or jsonl")
    <*> optional
      (strOption (long "out" <> metavar "PATH" <> help "Stream JSON page envelopes or JSONL trades into a private file"))

cryptoQuotesParser :: Parser CryptoQuotesCommand
cryptoQuotesParser =
  CryptoQuotesCommand
    <$> option (eitherReader parseSymbols)
      (long "symbols" <> metavar "PAIRS" <> help "Required: BTC/USD,ETH/USD,SOL/USD")
    <*> option (eitherReader parseLocation)
      (long "location" <> metavar "LOCATION" <> value Us <> help "us (default), us-1, us-2, eu-1, bs-1")
    <*> optional (option (eitherReader parseInstant)
      (long "start" <> metavar "RFC3339" <> help "Inclusive start date or timestamp"))
    <*> optional (option (eitherReader parseInstant)
      (long "end" <> metavar "RFC3339" <> help "Inclusive end date or timestamp"))
    <*> option (eitherReader parsePageLimit)
      (long "limit" <> metavar "N" <> value 1000 <> help "Quotes per page, 1..10000 (total across symbols)")
    <*> option (eitherReader parseSort)
      (long "sort" <> metavar "SORT" <> value BarsAsc <> help "asc (default) or desc")
    <*> option (eitherReader parseMaxPages)
      (long "max-pages" <> metavar "N" <> value 1 <> help "Maximum pages, 1..20 (default: 1)")
    <*> optional (option (eitherReader parsePageToken)
      (long "page-token" <> metavar "TOKEN" <> help "Resume from previous API pagination token"))
    <*> option (eitherReader parseBarsFormat)
      (long "format" <> metavar "FORMAT" <> value BarsJson <> help "json (default) or jsonl")
    <*> optional
      (strOption (long "out" <> metavar "PATH" <> help "Stream JSON page envelopes or JSONL quotes privately"))

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
          <> help "Asset class: crypto (CLI default), us_equity, us_option, crypto_perp, treasury, corporate, global_equity, us_index, us_equity_chain, ipo"
      )
    <*> optional
      ( option (eitherReader parseAssetStatus)
          ( long "status"
              <> metavar "STATUS"
              <> help "Filter by active, inactive, or all (default: no filter)"
          )
      )
    <*> optional
      (option (eitherReader parseAssetExchanges)
        (long "exchange" <> metavar "EXCHANGES" <> help "Comma-separated equity exchanges, or INDEX for us_index"))
    <*> optional
      (option (eitherReader parseAssetAttributes)
        (long "attributes" <> metavar "ATTRIBUTES" <> help "Comma-separated asset attributes (OR matching)"))
    <*> outputParser

orderParser :: Parser OrderCommand
orderParser =
  hsubparser
    (command "get"
      (info (GetOrder <$> orderGetParser)
        (progDesc "Fetch a single Alpaca paper order by UUID"))
      <> command "submit"
        (info (SubmitOrder <$> orderSubmitParser)
          (progDesc "Prepare a crypto paper order (dry run unless --confirm)"))
      <> command "cancel"
        (info (CancelOrder <$> orderCancelParser)
          (progDesc "Preview paper order cancellation; --confirm sends DELETE")))

orderSubmitParser :: Parser SubmitCommand
orderSubmitParser =
  SubmitCommand
    <$> option (eitherReader parseSubmitSymbol)
      (long "symbol" <> metavar "PAIR" <> help "One crypto pair, e.g. BTC/USD")
    <*> option (eitherReader parseSubmitSide)
      (long "side" <> metavar "SIDE" <> help "buy or sell")
    <*> option (eitherReader parseSubmitKind)
      (long "type" <> metavar "TYPE" <> help "market or limit")
    <*> option (eitherReader parseSubmitTimeInForce)
      (long "time-in-force" <> metavar "TIF" <> value SubmitGtc <> help "gtc (default) or ioc")
    <*> optional (option (eitherReader parseSubmitAmount)
      (long "qty" <> metavar "DECIMAL" <> help "Positive quantity; exclusive with --notional"))
    <*> optional (option (eitherReader parseSubmitAmount)
      (long "notional" <> metavar "DECIMAL" <> help "Positive amount; market only, exclusive with --qty"))
    <*> optional (option (eitherReader parseSubmitAmount)
      (long "limit-price" <> metavar "DECIMAL" <> help "Required for limit; forbidden for market"))
    <*> option (eitherReader parseClientOrderId)
      (long "client-order-id" <> metavar "ID" <> help "Required stable client identifier; do not reuse for different orders")
    <*> switch (long "confirm" <> help "Actually submit to Alpaca PAPER API; default is offline dry run")
    <*> outputParser

orderCancelParser :: Parser OrderCancelCommand
orderCancelParser =
  OrderCancelCommand
    <$> argument (eitherReader parseOrderId)
      (metavar "ORDER_ID" <> help "Server-issued UUID of the paper order to cancel")
    <*> switch (long "confirm" <> help "Actually send one DELETE to the PAPER API; default: offline dry run")

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
    <*> optional (option (eitherReader parseOrderTimestamp)
      (long "after" <> metavar "RFC3339" <> help "Exclusive submitted-at lower bound"))
    <*> optional (option (eitherReader parseOrderTimestamp)
      (long "until" <> metavar "RFC3339" <> help "Exclusive submitted-at upper bound"))
    <*> switch (long "nested" <> help "Roll up multi-leg orders in legs")
    <*> optional (option (eitherReader parseOrderSide)
      (long "side" <> metavar "SIDE" <> help "buy or sell"))
    <*> optional (option (eitherReader parseOrderAssetClasses)
      (long "asset-class" <> metavar "CLASSES" <> help "Comma-separated asset classes, or all"))
    <*> optional (option (eitherReader parseOrderId)
      (long "before-order-id" <> metavar "UUID" <> help "Orders before this UUID (exclusive); not with date bounds"))
    <*> optional (option (eitherReader parseOrderId)
      (long "after-order-id" <> metavar "UUID" <> help "Orders after this UUID (exclusive); not with date bounds"))

outputParser :: Parser (Maybe FilePath)
outputParser =
  optional
    ( strOption
        ( long "out"
            <> metavar "PATH"
            <> help "Write the complete JSON response to PATH"
        )
    )

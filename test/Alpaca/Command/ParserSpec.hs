{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.ParserSpec (spec) where

import Alpaca.Command.Account (AccountCommand (..))
import Alpaca.Command.Assets
  ( AssetClass (..), AssetStatus (..), AssetExchange (..), AssetAttribute (..), AssetsCommand (..))
import Alpaca.Command.Crypto.Bars
  ( BarsFormat (..)
  , BarsSort (..)
  , CryptoBarsCommand (..)
  , CryptoLocation (..)
  , parseInstant
  , parseTimeframe
  )
import Alpaca.Command.Crypto.Trades (CryptoTradesCommand (..))
import Alpaca.Command.Order (OrderCommand (..), OrderGetCommand (..), parseOrderId)
import Alpaca.Command.Orders
  ( OrderDirection (..), OrderStatus (..), OrdersCommand (..)
  , OrderSideFilter (..), OrderAssetClass (..)
  )
import Alpaca.Command.Positions (PositionsCommand (..))
import Alpaca.Command (Command (..))
import Alpaca.Command.Parser (commandParserInfo)
import Options.Applicative (defaultPrefs, execParserPure, getParseResult)
import Test.Hspec (Spec, it, shouldBe)

spec :: Spec
spec = do
  it "parses account without an output path" $
    parse ["account"] `shouldBe` Just (Account (AccountCommand Nothing))

  it "parses account with --out" $
    parse ["account", "--out", "account.json"]
      `shouldBe` Just (Account (AccountCommand (Just "account.json")))

  it "rejects --out without a path" $
    parse ["account", "--out"] `shouldBe` Nothing

  it "parses positions without output" $
    parse ["positions"] `shouldBe` Just (Positions (PositionsCommand Nothing))

  it "parses positions with --out" $
    parse ["positions", "--out", "positions.json"]
      `shouldBe` Just (Positions (PositionsCommand (Just "positions.json")))

  it "rejects positions --out without a path" $
    parse ["positions", "--out"] `shouldBe` Nothing

  it "rejects an unknown positions option" $
    parse ["positions", "--unexpected"] `shouldBe` Nothing

  it "defaults assets to the crypto class with no status filter" $
    parse ["assets"] `shouldBe` Just (Assets (AssetsCommand Crypto Nothing Nothing Nothing Nothing))

  it "parses all supported asset filters and JSON output" $
    parse ["assets", "--asset-class", "us_equity", "--status", "active", "--out", "assets.json"]
      `shouldBe` Just (Assets (AssetsCommand UsEquity (Just Active) Nothing Nothing (Just "assets.json")))

  it "parses an explicit crypto class and all statuses" $
    parse ["assets", "--asset-class", "crypto", "--status", "all"]
      `shouldBe` Just (Assets (AssetsCommand Crypto (Just All) Nothing Nothing Nothing))

  it "parses an inactive status" $
    parse ["assets", "--status", "inactive"]
      `shouldBe` Just (Assets (AssetsCommand Crypto (Just Inactive) Nothing Nothing Nothing))

  it "parses all asset filters together without dropping query parameters" $
    parse ["assets", "--asset-class", "us_equity", "--status", "active",
           "--exchange", "NASDAQ,NYSE", "--attributes", "has_options,ipo",
           "--out", "assets.json"]
      `shouldBe` Just (Assets (AssetsCommand UsEquity (Just Active)
        (Just [Nasdaq, Nyse]) (Just [HasOptions, IpoAttribute]) (Just "assets.json")))

  it "accepts the INDEX exchange for the us_index class" $
    parse ["assets", "--asset-class", "us_index", "--exchange", "INDEX"]
      `shouldBe` Just (Assets (AssetsCommand UsIndex Nothing (Just [Index]) Nothing Nothing))

  it "accepts every newly exposed asset class" $ do
    mapM_ (\(argument, expected) ->
      parse ["assets", "--asset-class", argument]
        `shouldBe` Just (Assets (AssetsCommand expected Nothing Nothing Nothing Nothing)))
      [ ("us_option", UsOption), ("crypto_perp", CryptoPerp)
      , ("treasury", Treasury), ("corporate", Corporate)
      , ("global_equity", GlobalEquity), ("us_equity_chain", UsEquityChain)
      , ("ipo", Ipo)
      ]

  it "rejects malformed or unknown assets exchanges and attributes" $ do
    parse ["assets", "--exchange", "NYSE,"] `shouldBe` Nothing
    parse ["assets", "--exchange", "CRYPTO"] `shouldBe` Nothing
    parse ["assets", "--attributes", "ipo,ipo"] `shouldBe` Nothing
    parse ["assets", "--attributes", "unknown"] `shouldBe` Nothing

  it "rejects an unsupported asset class or status" $ do
    parse ["assets", "--asset-class", "options"] `shouldBe` Nothing
    parse ["assets", "--status", "anything"] `shouldBe` Nothing

  it "rejects missing asset argument values" $ do
    parse ["assets", "--out"] `shouldBe` Nothing
    parse ["assets", "--status"] `shouldBe` Nothing
    parse ["assets", "--asset-class"] `shouldBe` Nothing
    parse ["assets", "--exchange"] `shouldBe` Nothing
    parse ["assets", "--attributes"] `shouldBe` Nothing

  it "rejects unknown assets options" $
    parse ["assets", "--unexpected"] `shouldBe` Nothing

  it "defaults order listing to open, descending, API-default limit" $
    parse ["orders"] `shouldBe` Just (Orders (OrdersCommand OrdersOpen Nothing Nothing Desc Nothing Nothing Nothing False Nothing Nothing Nothing Nothing))

  it "parses all order filters and original JSON output" $
    parse ["orders", "--status", "all", "--limit", "500", "--symbols", "BTCUSD, ETHUSD,AAPL", "--direction", "asc", "--out", "orders.json"]
      `shouldBe` Just (Orders (OrdersCommand OrdersAll (Just 500) (Just ["BTCUSD", "ETHUSD", "AAPL"]) Asc (Just "orders.json") Nothing Nothing False Nothing Nothing Nothing Nothing))

  it "parses closed orders and a smaller limit" $
    parse ["orders", "--status", "closed", "--limit", "20"]
      `shouldBe` Just (Orders (OrdersCommand OrdersClosed (Just 20) Nothing Desc Nothing Nothing Nothing False Nothing Nothing Nothing Nothing))

  it "rejects unsupported status, direction, or symbols" $ do
    parse ["orders", "--status", "filled"] `shouldBe` Nothing
    parse ["orders", "--direction", "up"] `shouldBe` Nothing
    parse ["orders", "--symbols", "BTC/USD"] `shouldBe` Nothing
    parse ["orders", "--symbols", "BTCUSD,,ETHUSD"] `shouldBe` Nothing

  it "rejects nonpositive and excessive order limits" $ do
    parse ["orders", "--limit", "0"] `shouldBe` Nothing
    parse ["orders", "--limit", "501"] `shouldBe` Nothing
    parse ["orders", "--limit", "garbage"] `shouldBe` Nothing

  it "rejects missing order option values" $ do
    mapM_ (\flag -> parse ["orders", flag] `shouldBe` Nothing)
      ["--limit", "--status", "--symbols", "--direction", "--out"]


  it "parses all eleven provider order filters together" $ do
    let after = either error id (parseInstant "2026-11-12T00:00:00.123456789Z")
        until = either error id (parseInstant "2026-11-12T04:00:00+01:00")
    parse
      [ "orders", "--status", "all", "--limit", "500"
      , "--symbols", "BTCUSD,AAPL", "--direction", "asc"
      , "--after", "2026-11-12T00:00:00.123456789Z"
      , "--until", "2026-11-12T04:00:00+01:00"
      , "--nested", "--side", "buy", "--asset-class", "us_equity,crypto"
      , "--out", "orders.json"
      ]
      `shouldBe` Just (Orders (OrdersCommand OrdersAll (Just 500)
        (Just ["BTCUSD", "AAPL"]) Asc (Just "orders.json")
        (Just after) (Just until) True (Just Buy)
        (Just [OrderAssetClass UsEquity, OrderAssetClass Crypto]) Nothing Nothing))

  it "parses before-order-id and after-order-id UUID anchors separately" $ do
    let uuid = "9275f66a-0a1b-4a22-8c55-167416c7cf14"
        cursor = either error id (parseOrderId uuid)
        defaultOptions = OrdersCommand OrdersOpen Nothing Nothing Desc Nothing
          Nothing Nothing False Nothing Nothing Nothing Nothing
    parse ["orders", "--before-order-id", uuid]
      `shouldBe` Just (Orders (defaultOptions { ordersBeforeOrderId = Just cursor }))
    parse ["orders", "--after-order-id", uuid]
      `shouldBe` Just (Orders (defaultOptions { ordersAfterOrderId = Just cursor }))

  it "parses one nested, side, and special all-classes filter" $
    parse ["orders", "--nested", "--side", "sell", "--asset-class", "all"]
      `shouldBe` Just (Orders (OrdersCommand OrdersOpen Nothing Nothing Desc Nothing
        Nothing Nothing True (Just Sell) (Just [OrderAllClasses]) Nothing Nothing))

  it "rejects malformed or unknown new order options while parsing" $ do
    mapM_ (\(flag, argument) -> parse ["orders", flag, argument] `shouldBe` Nothing)
      [ ("--after", "yesterday"), ("--after", "2026-11-12")
      , ("--until", "2026-11-12T12:30:00")
      , ("--side", "BUY"), ("--side", "both")
      , ("--asset-class", "crypto,crypto"), ("--asset-class", "all,crypto")
      , ("--asset-class", "BTCUSD")
      , ("--before-order-id", "not-a-uuid"), ("--after-order-id", "../positions")
      ]
    mapM_ (\flag -> parse ["orders", flag] `shouldBe` Nothing)
      [ "--after", "--until", "--side", "--asset-class"
      , "--before-order-id", "--after-order-id" ]

  it "parses a single order lookup by UUID" $ do
    let uuid = "9275f66a-0a1b-4a22-8c55-167416c7cf14"
        orderId = either error id (parseOrderId uuid)
    parse ["order", "get", uuid]
      `shouldBe` Just (Order (GetOrder (OrderGetCommand orderId False Nothing)))

  it "parses nested lookup and private JSON output" $ do
    let uuid = "9275f66a-0a1b-4a22-8c55-167416c7cf14"
        orderId = either error id (parseOrderId uuid)
    parse ["order", "get", uuid, "--nested", "--out", "order.json"]
      `shouldBe` Just (Order (GetOrder (OrderGetCommand orderId True (Just "order.json"))))

  it "rejects a missing, blank or malformed order ID" $ do
    parse ["order", "get"] `shouldBe` Nothing
    parse ["order", "get", ""] `shouldBe` Nothing
    parse ["order", "get", "not-a-uuid"] `shouldBe` Nothing
    parse ["order", "get", "../account"] `shouldBe` Nothing

  it "rejects missing output paths and unexpected order-get options" $ do
    let uuid = "9275f66a-0a1b-4a22-8c55-167416c7cf14"
    parse ["order", "get", uuid, "--out"] `shouldBe` Nothing
    parse ["order", "get", uuid, "--unknown"] `shouldBe` Nothing
    parse ["order", "unknown", uuid] `shouldBe` Nothing
    parse ["order"] `shouldBe` Nothing

  it "rejects an unknown order option" $
    parse ["orders", "--unexpected"] `shouldBe` Nothing

  it "parses historical crypto bars with safe one-page defaults" $ do
    let timeframe = either error id (parseTimeframe "1Hour")
    parse ["crypto", "bars", "--symbols", "BTC/USD,ETH/USD", "--timeframe", "1Hour"]
      `shouldBe` Just (CryptoBars (CryptoBarsCommand
        ["BTC/USD", "ETH/USD"] Us timeframe Nothing Nothing 1000 BarsAsc 1 Nothing BarsJson Nothing))

  it "parses all historical crypto bar filters and JSONL output" $ do
    let timeframe = either error id (parseTimeframe "5Min")
        start = either error id (parseInstant "2026-10-02T00:00:00Z")
        end = either error id (parseInstant "2026-10-02T02:00:00Z")
    parse ["crypto", "bars", "--symbols", "SOL/USD", "--location", "us-1",
           "--timeframe", "5Min", "--start", "2026-10-02T00:00:00Z",
           "--end", "2026-10-02T02:00:00Z", "--limit", "10000",
           "--sort", "desc", "--max-pages", "20", "--page-token", "ABC+/==",
           "--format", "jsonl", "--out", "bars.jsonl"]
      `shouldBe` Just (CryptoBars (CryptoBarsCommand
        ["SOL/USD"] Us1 timeframe (Just start) (Just end) 10000 BarsDesc
        20 (Just "ABC+/==") BarsJsonl (Just "bars.jsonl")))

  it "rejects invalid or missing historical crypto parameters before IO" $ do
    let base = ["crypto", "bars"]
    parse base `shouldBe` Nothing
    parse (base <> ["--symbols", "BTC/USD"]) `shouldBe` Nothing
    parse (base <> ["--timeframe", "1Min"]) `shouldBe` Nothing
    mapM_ (\flags -> parse (base <> ["--symbols", "BTC/USD", "--timeframe", "1Min"] <> flags)
      `shouldBe` Nothing)
      [["--limit", "10001"], ["--limit", "0"], ["--max-pages", "21"],
       ["--timeframe", "0Min"], ["--location", "hostile"],
       ["--symbols", "BTC/USD,,ETH/USD"], ["--start", "yesterday"],
       ["--format", "csv"], ["--sort", "random"], ["--page-token", ""],
       ["--out"], ["--unknown"]]

  it "parses crypto trades with the shared safe one-page defaults" $ do
    parse ["crypto", "trades", "--symbols", "BTC/USD,ETH/USD"]
      `shouldBe` Just (CryptoTrades (CryptoTradesCommand
        ["BTC/USD", "ETH/USD"] Us Nothing Nothing 1000 BarsAsc 1 Nothing BarsJson Nothing))

  it "parses all trades filters including JSONL output" $ do
    let start = either error id (parseInstant "2026-10-02T00:00:00Z")
        end = either error id (parseInstant "2026-10-02T02:00:00Z")
    parse ["crypto", "trades", "--symbols", "SOL/USD", "--location", "us-1",
           "--start", "2026-10-02T00:00:00Z", "--end", "2026-10-02T02:00:00Z",
           "--limit", "10000", "--sort", "desc", "--max-pages", "20",
           "--page-token", "ABC+/==", "--format", "jsonl", "--out", "trades.jsonl"]
      `shouldBe` Just (CryptoTrades (CryptoTradesCommand
        ["SOL/USD"] Us1 (Just start) (Just end) 10000 BarsDesc 20
        (Just "ABC+/==") BarsJsonl (Just "trades.jsonl")))

  it "rejects bad crypto trades arguments before authenticated I/O" $ do
    let base = ["crypto", "trades"]
    parse base `shouldBe` Nothing
    mapM_ (\flags -> parse (base <> ["--symbols", "BTC/USD"] <> flags)
      `shouldBe` Nothing)
      [["--limit", "10001"], ["--limit", "0"], ["--max-pages", "21"],
       ["--timeframe", "1Min"], ["--location", "hostile"],
       ["--symbols", "BTC/USD,,ETH/USD"], ["--start", "yesterday"],
       ["--format", "csv"], ["--sort", "random"], ["--page-token", ""],
       ["--out"], ["--unknown"]]

  it "rejects an unknown option" $
    parse ["account", "--unexpected"] `shouldBe` Nothing

  it "rejects an unknown subcommand" $
    parse ["unknown"] `shouldBe` Nothing

  it "requires a subcommand" $
    parse [] `shouldBe` Nothing

parse :: [String] -> Maybe Command
parse = getParseResult . execParserPure defaultPrefs commandParserInfo

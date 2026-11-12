module Alpaca.Command.ParserSpec (spec) where

import Alpaca.Command.Account (AccountCommand (..))
import Alpaca.Command.Assets (AssetClass (..), AssetStatus (..), AssetsCommand (..))
import Alpaca.Command.Positions (PositionsCommand (..))
import Alpaca.Command.Orders (OrdersCommand (..), OrderFilter (..), OrderDirection (..))
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
    parse ["assets"] `shouldBe` Just (Assets (AssetsCommand Crypto Nothing Nothing))

  it "parses all supported asset filters and JSON output" $
    parse ["assets", "--asset-class", "us_equity", "--status", "active", "--out", "assets.json"]
      `shouldBe` Just (Assets (AssetsCommand UsEquity (Just Active) (Just "assets.json")))

  it "parses an explicit crypto class and all statuses" $
    parse ["assets", "--asset-class", "crypto", "--status", "all"]
      `shouldBe` Just (Assets (AssetsCommand Crypto (Just All) Nothing))

  it "parses an inactive status" $
    parse ["assets", "--status", "inactive"]
      `shouldBe` Just (Assets (AssetsCommand Crypto (Just Inactive) Nothing))

  it "rejects an unsupported asset class or status" $ do
    parse ["assets", "--asset-class", "options"] `shouldBe` Nothing
    parse ["assets", "--status", "anything"] `shouldBe` Nothing

  it "rejects missing asset argument values" $ do
    parse ["assets", "--out"] `shouldBe` Nothing
    parse ["assets", "--status"] `shouldBe` Nothing
    parse ["assets", "--asset-class"] `shouldBe` Nothing

  it "rejects unknown assets options" $
    parse ["assets", "--unexpected"] `shouldBe` Nothing

  it "defaults orders to open and descending with no limit" $
    parse ["orders"] `shouldBe`
      Just (Orders (OrdersCommand OpenOrders Nothing [] Descending Nothing))

  it "accepts filters and repeated symbols with --out" $
    parse ["orders", "--status", "all", "--limit", "100", "--symbol", "BTCUSD",
           "--symbol", "AAPL", "--direction", "asc", "--out", "orders.json"]
      `shouldBe`
        Just (Orders (OrdersCommand AllOrders (Just 100) ["BTCUSD", "AAPL"] Ascending (Just "orders.json")))

  it "accepts closed orders and crypto symbols containing a slash" $
    parse ["orders", "--status", "closed", "--symbol", "BTC/USD"]
      `shouldBe`
        Just (Orders (OrdersCommand ClosedOrders Nothing ["BTC/USD"] Descending Nothing))

  it "rejects invalid order parameters and missing arguments" $ do
    map parse [["orders", "--limit", "0"], ["orders", "--limit", "501"],
               ["orders", "--limit", "abc"], ["orders", "--status", "pending"],
               ["orders", "--direction", "random"], ["orders", "--symbol", "AAPL,MSFT"],
               ["orders", "--symbol"], ["orders", "--out"],
               ["orders", "--unknown"]]
      `shouldBe` replicate 9 Nothing

  it "rejects an unknown option" $
    parse ["account", "--unexpected"] `shouldBe` Nothing

  it "rejects an unknown subcommand" $
    parse ["unknown"] `shouldBe` Nothing

  it "requires a subcommand" $
    parse [] `shouldBe` Nothing

parse :: [String] -> Maybe Command
parse = getParseResult . execParserPure defaultPrefs commandParserInfo

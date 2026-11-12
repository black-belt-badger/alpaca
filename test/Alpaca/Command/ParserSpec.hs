module Alpaca.Command.ParserSpec (spec) where

import Alpaca.Command.Account (AccountCommand (..))
import Alpaca.Command.Assets (AssetClass (..), AssetStatus (..), AssetsCommand (..))
import Alpaca.Command.Order (OrderCommand (..), OrderGetCommand (..), parseOrderId)
import Alpaca.Command.Orders (OrderDirection (..), OrderStatus (..), OrdersCommand (..))
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

  it "defaults order listing to open, descending, API-default limit" $
    parse ["orders"] `shouldBe` Just (Orders (OrdersCommand OrdersOpen Nothing Nothing Desc Nothing))

  it "parses all order filters and original JSON output" $
    parse ["orders", "--status", "all", "--limit", "500", "--symbols", "BTCUSD, ETHUSD,AAPL", "--direction", "asc", "--out", "orders.json"]
      `shouldBe` Just (Orders (OrdersCommand OrdersAll (Just 500) (Just ["BTCUSD", "ETHUSD", "AAPL"]) Asc (Just "orders.json")))

  it "parses closed orders and a smaller limit" $
    parse ["orders", "--status", "closed", "--limit", "20"]
      `shouldBe` Just (Orders (OrdersCommand OrdersClosed (Just 20) Nothing Desc Nothing))

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

  it "rejects an unknown option" $
    parse ["account", "--unexpected"] `shouldBe` Nothing

  it "rejects an unknown subcommand" $
    parse ["unknown"] `shouldBe` Nothing

  it "requires a subcommand" $
    parse [] `shouldBe` Nothing

parse :: [String] -> Maybe Command
parse = getParseResult . execParserPure defaultPrefs commandParserInfo

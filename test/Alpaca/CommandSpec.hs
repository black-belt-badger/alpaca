module Alpaca.CommandSpec (spec) where

import Alpaca.Command.Account (AccountCommand (..), AccountFormat (..))
import Alpaca.Command.Assets (AssetClass (Crypto), AssetsCommand (..))
import Alpaca.Command.Order (OrderCommand (..), OrderGetCommand (..), parseOrderId)
import Alpaca.Command.Orders (OrderDirection (Desc), OrderStatus (OrdersOpen), OrdersCommand (..))
import Alpaca.Command.Positions (PositionsCommand (..), PositionsFormat (..), parsePositionsFormat)
import Alpaca.Command (Command (..))
import Test.Hspec (Spec, it, shouldBe)

spec :: Spec
spec = do
  it "wraps account command options" $
    Account (AccountCommand (Just "account.json") AccountText False)
      `shouldBe` Account (AccountCommand (Just "account.json") AccountText False)

  it "wraps positions command options" $
    Positions (PositionsCommand Nothing PositionsText False)
      `shouldBe` Positions (PositionsCommand Nothing PositionsText False)

  it "distinguishes account and positions" $
    Account (AccountCommand Nothing AccountText False) == Positions (PositionsCommand Nothing PositionsText False)
      `shouldBe` False

  it "distinguishes assets from account and positions" $ do
    let assets = Assets (AssetsCommand Crypto Nothing Nothing Nothing Nothing)
    assets == Account (AccountCommand Nothing AccountText False) `shouldBe` False
    assets == Positions (PositionsCommand Nothing PositionsText False) `shouldBe` False

  it "distinguishes order listing from other commands" $ do
    let orders = Orders (OrdersCommand OrdersOpen Nothing Nothing Desc Nothing Nothing Nothing False Nothing Nothing Nothing Nothing)
    orders == Account (AccountCommand Nothing AccountText False) `shouldBe` False
    orders == Assets (AssetsCommand Crypto Nothing Nothing Nothing Nothing) `shouldBe` False
    orders == Positions (PositionsCommand Nothing PositionsText False) `shouldBe` False

  it "distinguishes single order get from listing" $ do
    let orderId = either error id (parseOrderId "9275f66a-0a1b-4a22-8c55-167416c7cf14")
        order = Order (GetOrder (OrderGetCommand orderId False Nothing))
    order == Orders (OrdersCommand OrdersOpen Nothing Nothing Desc Nothing Nothing Nothing False Nothing Nothing Nothing Nothing) `shouldBe` False

  it "distinguishes different account command options" $
    (Account (AccountCommand Nothing AccountText False) == Account (AccountCommand (Just "account.json") AccountText False))
      `shouldBe` False

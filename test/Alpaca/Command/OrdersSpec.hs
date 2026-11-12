{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.OrdersSpec (spec) where

import Alpaca.Command.Orders
  ( OrderFilter (..)
  , OrderDirection (..)
  , OrdersCommand (..)
  , orderFilterParameter
  , orderDirectionParameter
  , parseOrderFilter
  , parseOrderDirection
  , parseOrderLimit
  , parseOrderSymbol
  )
import Test.Hspec (Spec, it, shouldBe)

spec :: Spec
spec = do
  it "encodes allowed order statuses" $ do
    map orderFilterParameter [OpenOrders, ClosedOrders, AllOrders]
      `shouldBe` ["open", "closed", "all"]
    parseOrderFilter "all" `shouldBe` Right AllOrders
    parseOrderFilter "pending" `shouldBe` Left "Expected open, closed, or all"

  it "encodes order directions" $ do
    map orderDirectionParameter [Ascending, Descending]
      `shouldBe` ["asc", "desc"]
    parseOrderDirection "asc" `shouldBe` Right Ascending
    parseOrderDirection "bad" `shouldBe` Left "Expected asc or desc"

  it "validates limit boundaries" $ do
    parseOrderLimit "1" `shouldBe` Right 1
    parseOrderLimit "500" `shouldBe` Right 500
    map parseOrderLimit ["0", "-1", "501", "1.5", "x", "99999999999999999"]
      `shouldBe` replicate 6 (Left "Expected a whole number between 1 and 500")

  it "validates a single stock or crypto symbol" $ do
    parseOrderSymbol "BTCUSD" `shouldBe` Right "BTCUSD"
    parseOrderSymbol "BTC/USD" `shouldBe` Right "BTC/USD"
    parseOrderSymbol "BRK.B" `shouldBe` Right "BRK.B"
    map parseOrderSymbol ["", "AAPL,MSFT", "BTC USD", "BTC&limit=500"]
      `shouldBe` replicate 4 (Left "Expected a nonempty symbol (letters, digits, /, ., _, -)")

  it "retains the output path for saving raw JSON" $
    ordersOutput (OrdersCommand AllOrders (Just 10) ["BTCUSD"] Descending (Just "orders.json"))
      `shouldBe` Just "orders.json"

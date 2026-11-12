{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.OrdersSpec (spec) where

import Alpaca.Command.Orders
  ( OrderStatus (..)
  , OrderDirection (..)
  , parseOrderStatus
  , parseOrderDirection
  , parseOrderLimit
  , parseOrderSymbols
  , orderStatusParameter
  , orderDirectionParameter
  )
import Data.Either (isLeft)
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

spec :: Spec
spec = do
  it "accepts all supported order status values" $ do
    parseOrderStatus "open" `shouldBe` Right OrdersOpen
    parseOrderStatus "closed" `shouldBe` Right OrdersClosed
    parseOrderStatus "all" `shouldBe` Right OrdersAll
    orderStatusParameter OrdersOpen `shouldBe` "open"
    orderStatusParameter OrdersClosed `shouldBe` "closed"
    orderStatusParameter OrdersAll `shouldBe` "all"

  it "accepts only ascending or descending sort directions" $ do
    parseOrderDirection "asc" `shouldBe` Right Asc
    parseOrderDirection "desc" `shouldBe` Right Desc
    orderDirectionParameter Asc `shouldBe` "asc"
    orderDirectionParameter Desc `shouldBe` "desc"
    parseOrderDirection "newest" `shouldSatisfy` isLeft

  it "rejects unsupported order status" $
    parseOrderStatus "filled" `shouldSatisfy` isLeft

  it "validates Alpaca's inclusive limit range" $ do
    parseOrderLimit "1" `shouldBe` Right 1
    parseOrderLimit "50" `shouldBe` Right 50
    parseOrderLimit "500" `shouldBe` Right 500

  it "rejects invalid or overflowing limits before IO" $
    mapM_ (\n -> parseOrderLimit n `shouldSatisfy` isLeft)
      ["", "0", "501", "-1", "1.5", "5x", " 5", "9999999999999999999999999999999999"]

  it "parses comma-separated crypto and equity symbols" $ do
    parseOrderSymbols "BTCUSD, ETHUSD,AAPL,BRK.B"
      `shouldBe` Right ["BTCUSD", "ETHUSD", "AAPL", "BRK.B"]
    parseOrderSymbols "SOLUSD" `shouldBe` Right ["SOLUSD"]

  it "rejects empty, invalid, or noncanonical symbols" $
    mapM_ (\s -> parseOrderSymbols s `shouldSatisfy` isLeft)
      ["", "BTCUSD,", ",ETHUSD", "BTCUSD,,ETHUSD", "BTC/USD", "btcUSD", "BTCUSD&status=all"]

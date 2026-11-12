{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Orders.RunSpec (spec) where

import Alpaca.Command.Orders.Run (renderOrdersSummary)
import Alpaca.Domain.Order (Order (..))
import qualified Data.Text as Text
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

spec :: Spec
spec = do
  it "renders an empty order history clearly" $
    renderOrdersSummary [] `shouldBe` "Kirke — Alpaca paper orders\nNo matching orders.\n"

  it "shows order details and exact decimals" $ do
    let summary = renderOrdersSummary [crypto]
    summary `shouldSatisfy` Text.isPrefixOf "Kirke — Alpaca paper orders\nOrders: 1\n"
    summary `shouldSatisfy` Text.isInfixOf "BTCUSD (crypto, buy market, filled)\n"
    summary `shouldSatisfy` Text.isInfixOf "  ID: id-1\n"
    summary `shouldSatisfy` Text.isInfixOf "  Client order ID: cid-1\n"
    summary `shouldSatisfy` Text.isInfixOf "  Quantity: 0.00000000123456789\n"
    summary `shouldSatisfy` Text.isInfixOf "  Filled average price: 90000.123456789\n"

  it "prints sensible text for missing nullable fields" $ do
    let summary = renderOrdersSummary [crypto {orderNotional = Nothing, orderFilledAt = Nothing}]
    summary `shouldSatisfy` Text.isInfixOf "  Notional: not provided\n"
    summary `shouldSatisfy` Text.isInfixOf "  Filled at: not provided\n"

crypto :: Order
crypto =
  Order
    "id-1"
    "cid-1"
    "BTCUSD"
    (Just "crypto")
    "buy"
    "market"
    "filled"
    (Just "0.00000000123456789")
    Nothing
    "0.00000000123456789"
    (Just "90000.123456789")
    Nothing
    Nothing
    "2026-11-12T22:00:00Z"
    (Just "2026-11-12T22:00:00Z")
    (Just "2026-11-12T22:00:01Z")

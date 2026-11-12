{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Orders.RunSpec (spec) where

import Alpaca.Command.Orders.Run (renderOrdersSummary)
import Alpaca.Domain.Order (Order (..))
import qualified Data.Text as Text
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

spec :: Spec
spec = do
  it "shows a clear message for no matching orders" $
    shouldBe (renderOrdersSummary []) "Kirke — Alpaca paper orders\nNo matching orders.\n"

  it "renders an order summary with exact quantity and optional values" $ do
    let summary = renderOrdersSummary [example]
    shouldSatisfy summary (Text.isInfixOf "Orders: 1\n")
    shouldSatisfy summary (Text.isInfixOf "BTCUSD (buy, market, filled)\n")
    shouldSatisfy summary (Text.isInfixOf "Order ID: order-123\n")
    shouldSatisfy summary (Text.isInfixOf "Quantity: 0.000123456789\n")
    shouldSatisfy summary (Text.isInfixOf "Limit price: not provided\n")
    shouldSatisfy summary (Text.isInfixOf "Submitted: 2026-11-12T01:00:00Z\n")

example :: Order
example =
  Order "order-123" Nothing "BTCUSD" "buy" "market" "filled"
    (Just "0.000123456789") Nothing (Just "0.000123456789")
    Nothing Nothing (Just "2026-11-12T01:00:00Z") Nothing

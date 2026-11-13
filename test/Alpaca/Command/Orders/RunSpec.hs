{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Orders.RunSpec (spec) where

import Alpaca.Command.Orders.Run (renderOrderSummary, renderOrdersSummary)
import Alpaca.Domain.Order (Order (..), decodeOrder)
import qualified Data.Text as Text
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

spec :: Spec
spec = do
  it "renders an empty order history clearly" $
    renderOrdersSummary [] `shouldBe` "Kirke — Alpaca paper orders\nNo matching orders.\n"

  it "renders a single order using the same details as the listing" $ do
    let summary = renderOrderSummary crypto
    summary `shouldSatisfy` Text.isPrefixOf "Kirke — Alpaca paper order\n"
    summary `shouldSatisfy` Text.isInfixOf "BTCUSD (crypto, buy market, filled)\n"
    summary `shouldSatisfy` Text.isInfixOf "  ID: id-1\n"
    summary `shouldSatisfy` Text.isInfixOf "  Quantity: 0.00000000123456789\n"

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
  case decodeOrder "{\"id\":\"id-1\",\"client_order_id\":\"cid-1\",\"symbol\":\"BTCUSD\",\"asset_class\":\"crypto\",\"side\":\"buy\",\"type\":\"market\",\"status\":\"filled\",\"qty\":\"0.00000000123456789\",\"filled_qty\":\"0.00000000123456789\",\"filled_avg_price\":\"90000.123456789\",\"created_at\":\"2026-11-12T22:00:00Z\",\"submitted_at\":\"2026-11-12T22:00:00Z\",\"filled_at\":\"2026-11-12T22:00:01Z\"}" of
    Right value -> value
    Left failure -> error ("Invalid synthetic order fixture: " <> failure)

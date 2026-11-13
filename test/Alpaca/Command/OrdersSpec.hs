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
  , OrdersCommand (..)
  , OrderSideFilter (..)
  , OrderAssetClass (..)
  , parseOrderSide
  , parseOrderAssetClasses
  , parseOrderTimestamp
  , orderSideParameter
  , orderAssetClassParameter
  , validateOrdersCommand
  )
import Alpaca.Command.Assets (AssetClass (..))
import Alpaca.Command.Crypto.Bars (BarsInstant, instantParameter)
import Alpaca.Command.Order (OrderId, parseOrderId)
import qualified Data.ByteString.Char8 as Char8
import qualified Data.Text as Text
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


  it "accepts documented buy/sell filters only" $ do
    parseOrderSide "buy" `shouldBe` Right Buy
    parseOrderSide "sell" `shouldBe` Right Sell
    orderSideParameter Buy `shouldBe` "buy"
    orderSideParameter Sell `shouldBe` "sell"
    mapM_ (\value -> parseOrderSide value `shouldSatisfy` isLeft)
      ["", "BUY", "short", "both", "buy&limit=500"]

  it "accepts all ten documented asset classes and the special all selector" $ do
    let classes =
          [ ("us_equity", UsEquity), ("us_option", UsOption)
          , ("crypto", Crypto), ("crypto_perp", CryptoPerp)
          , ("treasury", Treasury), ("corporate", Corporate)
          , ("global_equity", GlobalEquity), ("us_index", UsIndex)
          , ("us_equity_chain", UsEquityChain), ("ipo", Ipo)
          ]
    mapM_ (\(wire, classValue) -> do
      parseOrderAssetClasses wire `shouldBe` Right [OrderAssetClass classValue]
      orderAssetClassParameter (OrderAssetClass classValue) `shouldBe` Char8.pack wire
      ) classes
    parseOrderAssetClasses "all" `shouldBe` Right [OrderAllClasses]
    orderAssetClassParameter OrderAllClasses `shouldBe` "all"
    parseOrderAssetClasses "crypto, us_equity,us_option"
      `shouldBe` Right [OrderAssetClass Crypto, OrderAssetClass UsEquity, OrderAssetClass UsOption]

  it "rejects empty, duplicate, unknown or contradictory class selectors" $
    mapM_ (\input -> parseOrderAssetClasses input `shouldSatisfy` isLeft)
      ["", ",", "crypto,", ",crypto", "crypto,,us_equity", "crypto,crypto"
      , "all,crypto", "us_equity,all", "BTCUSD", "CRYPTO", "crypto%2Cus_equity"]

  it "requires timezone-qualified RFC3339 after/until timestamps" $ do
    let exact = "2026-11-12T01:02:03.123456789Z"
        withOffset = "2026-11-12T02:02:03.123456789+01:00"
    fmap instantParameter (parseOrderTimestamp exact) `shouldBe` Right (Text.pack exact)
    fmap instantParameter (parseOrderTimestamp withOffset) `shouldBe` Right (Text.pack withOffset)
    mapM_ (\input -> parseOrderTimestamp input `shouldSatisfy` isLeft)
      ["", "2026-11-12", "2026-11-12T01:02:03", "yesterday",
       "2026-11-12T99:02:03Z", "2026-11-12T01:02:03Z&limit=500"]

  it "accepts properly ordered exclusive timestamp bounds with timezone offsets" $ do
    let opts = emptyOrders
          { ordersAfter = Just (stamp "2026-11-12T00:00:00Z")
          , ordersUntil = Just (stamp "2026-11-12T02:00:00+01:00")
          }
    validateOrdersCommand opts `shouldBe` Right opts

  it "rejects reversed timestamp bounds before any IO" $
    validateOrdersCommand (emptyOrders
      { ordersAfter = Just (stamp "2026-11-12T02:00:00Z")
      , ordersUntil = Just (stamp "2026-11-12T01:00:00Z")
      }) `shouldSatisfy` isLeft

  it "rejects simultaneous before-order-id and after-order-id anchors" $
    validateOrdersCommand (emptyOrders
      { ordersBeforeOrderId = Just (orderUuid "9275f66a-0a1b-4a22-8c55-167416c7cf14")
      , ordersAfterOrderId = Just (orderUuid "b27d45fe-0a1b-4a22-8c55-167416c7cf14")
      }) `shouldSatisfy` isLeft

  it "rejects either order-ID cursor mixed with either submitted-at bound" $ do
    let cursor = orderUuid "9275f66a-0a1b-4a22-8c55-167416c7cf14"
        start = stamp "2026-11-12T01:00:00Z"
    mapM_ (\opts -> validateOrdersCommand opts `shouldSatisfy` isLeft)
      [ emptyOrders { ordersBeforeOrderId = Just cursor, ordersAfter = Just start }
      , emptyOrders { ordersBeforeOrderId = Just cursor, ordersUntil = Just start }
      , emptyOrders { ordersAfterOrderId = Just cursor, ordersAfter = Just start }
      , emptyOrders { ordersAfterOrderId = Just cursor, ordersUntil = Just start }
      ]

  it "accepts either cursor alone, retaining independent filters" $ do
    let cursor = orderUuid "9275f66a-0a1b-4a22-8c55-167416c7cf14"
        before = emptyOrders { ordersBeforeOrderId = Just cursor, ordersSide = Just Buy }
        after = emptyOrders { ordersAfterOrderId = Just cursor, ordersNested = True }
    validateOrdersCommand before `shouldBe` Right before
    validateOrdersCommand after `shouldBe` Right after

  it "rejects programmatically empty asset-class filters" $
    validateOrdersCommand (emptyOrders { ordersAssetClasses = Just [] })
      `shouldSatisfy` isLeft

  it "rejects empty, invalid, or noncanonical symbols" $
    mapM_ (\s -> parseOrderSymbols s `shouldSatisfy` isLeft)
      ["", "BTCUSD,", ",ETHUSD", "BTCUSD,,ETHUSD", "BTC/USD", "btcUSD", "BTCUSD&status=all"]


emptyOrders :: OrdersCommand
emptyOrders =
  OrdersCommand OrdersOpen Nothing Nothing Desc Nothing
    Nothing Nothing False Nothing Nothing Nothing Nothing

stamp :: String -> BarsInstant
stamp = either error id . parseOrderTimestamp

orderUuid :: String -> OrderId
orderUuid = either error id . parseOrderId

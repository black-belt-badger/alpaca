{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Positions.RunSpec (spec) where

import Alpaca.Command.Positions.Run (renderPositionsSummary)
import Alpaca.Domain.Position (Position (..))
import qualified Data.Text as Text
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

spec :: Spec
spec = do
  it "explains an empty portfolio" $
    renderPositionsSummary []
      `shouldBe` "Kirke — Alpaca paper positions\nNo open positions.\n"

  it "renders quantities and monetary strings without rounding" $ do
    let summary = renderPositionsSummary [crypto, equity]
    summary `shouldSatisfy` Text.isPrefixOf "Kirke — Alpaca paper positions\nPositions: 2\n"
    summary `shouldSatisfy` Text.isInfixOf "BTCUSD (crypto, long)\n"
    summary `shouldSatisfy` Text.isInfixOf "  Quantity: 0.000997498123456789\n"
    summary `shouldSatisfy` Text.isInfixOf "  Market value: 67.123456789012345\n"
    summary `shouldSatisfy` Text.isInfixOf "  Unrealized P/L: -0.000000000001\n"
    summary `shouldSatisfy` Text.isInfixOf "AAPL (us_equity, short)\n"

  it "renders absent values without crashing" $
    renderPositionsSummary [crypto {positionMarketValue = Nothing, positionCurrentPrice = Nothing, positionUnrealizedPl = Nothing}]
      `shouldSatisfy` Text.isInfixOf "  Current price: not provided\n"

crypto :: Position
crypto = Position "BTCUSD" "crypto" "long" "0.000997498123456789" (Just "67.123456789012345") (Just "67291.12") (Just "-0.000000000001")

equity :: Position
equity = Position "AAPL" "us_equity" "short" "2" (Just "-400.50") (Just "200.25") (Just "50.50")

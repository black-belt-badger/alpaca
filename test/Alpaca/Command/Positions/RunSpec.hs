{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Positions.RunSpec (spec) where

import Alpaca.Command.Positions.Run (renderPositionsSummary)
import Alpaca.Domain.Position (Position, decodePositions)
import Data.Aeson (Value (..), object, encode, (.=))
import Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as Lazy
import qualified Data.Text as Text
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

spec :: Spec
spec = do
  it "explains an empty portfolio" $
    renderPositionsSummary []
      `shouldBe` "Kirke — Alpaca paper positions\nNo open positions.\n"

  it "renders quantities and monetary strings without rounding" $ do
    let summary = renderPositionsSummary positions
    summary `shouldSatisfy` Text.isPrefixOf "Kirke — Alpaca paper positions\nPositions: 2\n"
    summary `shouldSatisfy` Text.isInfixOf "BTCUSD (crypto, long)\n"
    summary `shouldSatisfy` Text.isInfixOf "  Quantity: 0.000997498123456789\n"
    summary `shouldSatisfy` Text.isInfixOf "  Market value: 67.123456789012345\n"
    summary `shouldSatisfy` Text.isInfixOf "  Current price: 67291.12\n"
    summary `shouldSatisfy` Text.isInfixOf "  Unrealized P/L: -0.000000000001\n"
    summary `shouldSatisfy` Text.isInfixOf "AAPL (us_equity, short)\n"
    summary `shouldSatisfy` Text.isInfixOf "  Market value: -400.50\n"

  it "does not expose asset IDs or nested USD cost basis in the concise summary" $ do
    let summary = renderPositionsSummary positions
    summary `shouldSatisfy` (not . Text.isInfixOf "00000000-0000-0000-0000-000000000001")
    summary `shouldSatisfy` (not . Text.isInfixOf "private-example")

  it "keeps unfamiliar future enum strings readable" $ do
    let future = fixture "X" "future_class" "FUTURE" "pending" "0" "0"
        summary = renderPositionsSummary (decodeFixture (Lazy.toStrict (encode [future])))
    summary `shouldSatisfy` Text.isInfixOf "X (future_class, pending)\n"

positions :: [Position]
positions =
  decodeFixture
    (Lazy.toStrict
      (encode
        [ fixture "BTCUSD" "crypto" "CRYPTO" "long" "0.000997498123456789" "67.123456789012345"
        , fixture "AAPL" "us_equity" "NASDAQ" "short" "2" "-400.50"
        ]))

decodeFixture :: ByteString -> [Position]
decodeFixture input = either error id (decodePositions input)

fixture :: Text.Text -> Text.Text -> Text.Text -> Text.Text -> Text.Text -> Text.Text -> Value
fixture symbol assetClass exchange side qty marketValue =
  object
    [ "asset_id" .= String "00000000-0000-0000-0000-000000000001"
    , "asset_class" .= assetClass
    , "exchange" .= exchange
    , "asset_marginable" .= Bool False
    , "symbol" .= symbol
    , "side" .= side
    , "qty" .= qty
    , "avg_entry_price" .= String "67123.00000000000000001"
    , "change_today" .= String "0.001"
    , "cost_basis" .= String "68.00"
    , "current_price" .= String "67291.12"
    , "lastday_price" .= String "66500.50"
    , "market_value" .= marketValue
    , "unrealized_intraday_pl" .= String "0.5"
    , "unrealized_intraday_plpc" .= String "0.005"
    , "unrealized_pl" .= String "-0.000000000001"
    , "unrealized_plpc" .= String "-0.000000001"
    ]

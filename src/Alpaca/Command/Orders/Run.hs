{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Orders.Run
  ( runOrders
  , renderOrdersSummary
  , renderOrderSummary
  ) where

import Alpaca.Client (alpacaErrorMessage, fetchOrders)
import Alpaca.Command.Orders (OrdersCommand (..))
import Alpaca.Credentials (credentialErrorMessage, loadCredentials)
import Alpaca.Domain.Order (Order (..), decodeOrders)
import Alpaca.Output (savePrivateJson)
import Control.Exception (IOException, displayException, try)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import System.Exit (die)

runOrders :: OrdersCommand -> IO ()
runOrders options = do
  credentials <- loadCredentials >>= either (die . credentialErrorMessage) pure
  response <- fetchOrders credentials options
    >>= either (die . alpacaErrorMessage) pure
  orders <- either (die . ("Invalid Alpaca orders response: " <>)) pure (decodeOrders response)
  case ordersOutput options of
    Nothing -> TextIO.putStr (renderOrdersSummary orders)
    Just path -> do
      result <- try (savePrivateJson path response) :: IO (Either IOException ())
      case result of
        Left err -> die ("Could not save orders JSON: " <> displayException err)
        Right () -> putStrLn ("Saved complete orders JSON to " <> path)

renderOrdersSummary :: [Order] -> Text
renderOrdersSummary orders =
  Text.unlines $
    ["Kirke — Alpaca paper orders"]
      <> if null orders
        then ["No matching orders."]
        else ("Orders: " <> Text.pack (show (length orders))) : concatMap renderOrder orders

-- | Reuse the same field rendering for list and single-order lookups.
renderOrderSummary :: Order -> Text
renderOrderSummary order = Text.unlines ("Kirke — Alpaca paper order" : renderOrder order)

renderOrder :: Order -> [Text]
renderOrder order =
  [ orderSymbol order <> " (" <> value (orderAssetClass order) <> ", "
      <> orderSide order <> " " <> orderType order <> ", " <> orderState order <> ")"
  , "  ID: " <> orderId order
  , "  Client order ID: " <> orderClientOrderId order
  , "  Quantity: " <> value (orderQty order)
  , "  Notional: " <> value (orderNotional order)
  , "  Filled quantity: " <> orderFilledQty order
  , "  Filled average price: " <> value (orderFilledAvgPrice order)
  , "  Limit price: " <> value (orderLimitPrice order)
  , "  Stop price: " <> value (orderStopPrice order)
  , "  Created at: " <> orderCreatedAt order
  , "  Submitted at: " <> value (orderSubmittedAt order)
  , "  Filled at: " <> value (orderFilledAt order)
  ]
  where
    value = maybe "not provided" id

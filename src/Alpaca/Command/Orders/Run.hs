{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Orders.Run
  ( runOrders
  , renderOrdersSummary
  ) where

import Alpaca.Client (alpacaErrorMessage, fetchOrders)
import Alpaca.Command.Orders (OrdersCommand (..))
import Alpaca.Credentials (credentialErrorMessage, loadCredentials)
import Alpaca.Domain.Order (Order (..), decodeOrders)
import Alpaca.Output (savePrivateJson)
import Control.Exception (IOException, displayException, try)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import System.Exit (die)

runOrders :: OrdersCommand -> IO ()
runOrders options = do
  credentials <- loadCredentials >>= either (die . credentialErrorMessage) pure
  response <- fetchOrders credentials options >>= either (die . alpacaErrorMessage) pure
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
    ["Kirke — Alpaca paper orders"] <>
      if null orders
        then ["No matching orders."]
        else ("Orders: " <> Text.pack (show (length orders))) : concatMap renderOrder orders

renderOrder :: Order -> [Text]
renderOrder order =
  [ orderSymbol order <> " (" <> orderSide order <> ", " <> orderType order <> ", " <> orderStatus order <> ")"
  , "  Order ID: " <> orderId order
  , "  Client order ID: " <> present (orderClientId order)
  , "  Quantity: " <> present (orderQuantity order)
  , "  Notional: " <> present (orderNotional order)
  , "  Filled quantity: " <> present (orderFilledQuantity order)
  , "  Limit price: " <> present (orderLimitPrice order)
  , "  Stop price: " <> present (orderStopPrice order)
  , "  Submitted: " <> present (orderSubmittedAt order)
  , "  Filled: " <> present (orderFilledAt order)
  ]
  where
    present = fromMaybe "not provided"

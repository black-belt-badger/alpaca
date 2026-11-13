{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Order.Run
  ( runOrder
  , runOrderGet
  , orderErrorMessage
  , decodeOrderLookup
  ) where

import Alpaca.Client (AlpacaError (..), alpacaErrorMessage, fetchOrder)
import Alpaca.Command.Order
  ( OrderCommand (..), OrderGetCommand (..), OrderId, orderIdSegment )
import Alpaca.Command.Order.Submit.Run (runSubmit)
import Alpaca.Command.Order.Cancel.Run (runOrderCancel)
import Alpaca.Command.Orders.Run (renderOrderSummary)
import Alpaca.Credentials (credentialErrorMessage, loadCredentials)
import Alpaca.Domain.Order (Order (..), decodeOrder)
import Alpaca.Output (savePrivateJson)
import Control.Exception (IOException, displayException, try)
import Data.ByteString (ByteString)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import System.Exit (die)

runOrder :: OrderCommand -> IO ()
runOrder (GetOrder options) = runOrderGet options
runOrder (SubmitOrder options) = runSubmit options
runOrder (CancelOrder options) = runOrderCancel options

runOrderGet :: OrderGetCommand -> IO ()
runOrderGet options = do
  credentials <- loadCredentials >>= either (die . credentialErrorMessage) pure
  response <- fetchOrder credentials options
  (order, raw) <- either die pure (decodeOrderLookup (getOrderId options) response)
  case getOrderOutput options of
    Nothing -> TextIO.putStr (renderOrderSummary order)
    Just path -> do
      result <- try (savePrivateJson path raw) :: IO (Either IOException ())
      case result of
        Left err -> die ("Could not save order JSON: " <> displayException err)
        Right () -> putStrLn ("Saved complete order JSON to " <> path)

-- | Pure, offline-testable order-by-ID response boundary. The raw provider
-- bytes are passed on unchanged for private --out files, including unknown
-- future properties and precise decimal literals.
--
-- The selected UUID must match the returned primary order ID; otherwise an
-- unrelated order could be displayed as the requested one. UUID comparisons
-- are case-insensitive (canonical hex may be supplied in either case).
--
-- Never include the provider's response, order ID or parser exception
-- messages in diagnostic output.
decodeOrderLookup :: OrderId -> Either AlpacaError ByteString -> Either String (Order, ByteString)
decodeOrderLookup requested result =
  case result of
    Left err -> Left (orderErrorMessage err)
    Right raw ->
      case decodeOrder raw of
        Left _ -> Left "Invalid Alpaca order response (expected one valid order object)."
        Right order
          | Text.toCaseFold (orderId order)
              == Text.toCaseFold (Text.pack (orderIdSegment requested)) -> Right (order, raw)
          | otherwise -> Left "Invalid Alpaca order response: order ID does not match requested UUID."

-- | Do not expose the provider's error body, request, or credentials.
-- A missing order is not an authentication or transport failure.
orderErrorMessage :: AlpacaError -> String
orderErrorMessage (UnexpectedStatus 404) = "Alpaca paper order not found (HTTP 404)."
orderErrorMessage err = alpacaErrorMessage err

{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Order.Run
  ( runOrder
  , runOrderGet
  , orderErrorMessage
  ) where

import Alpaca.Client (AlpacaError (..), alpacaErrorMessage, fetchOrder)
import Alpaca.Command.Order (OrderCommand (..), OrderGetCommand (..))
import Alpaca.Command.Orders.Run (renderOrderSummary)
import Alpaca.Credentials (credentialErrorMessage, loadCredentials)
import Alpaca.Domain.Order (decodeOrder)
import Alpaca.Output (savePrivateJson)
import Control.Exception (IOException, displayException, try)
import qualified Data.Text.IO as TextIO
import System.Exit (die)

runOrder :: OrderCommand -> IO ()
runOrder (GetOrder options) = runOrderGet options

runOrderGet :: OrderGetCommand -> IO ()
runOrderGet options = do
  credentials <- loadCredentials >>= either (die . credentialErrorMessage) pure
  response <- fetchOrder credentials options
    >>= either (die . orderErrorMessage) pure
  order <- either (die . ("Invalid Alpaca order response: " <>)) pure (decodeOrder response)
  case getOrderOutput options of
    Nothing -> TextIO.putStr (renderOrderSummary order)
    Just path -> do
      result <- try (savePrivateJson path response) :: IO (Either IOException ())
      case result of
        Left err -> die ("Could not save order JSON: " <> displayException err)
        Right () -> putStrLn ("Saved complete order JSON to " <> path)

-- | Do not expose the provider's error body, request, or credentials.
-- A missing order is not an authentication or transport failure.
orderErrorMessage :: AlpacaError -> String
orderErrorMessage (UnexpectedStatus 404) = "Alpaca paper order not found (HTTP 404)."
orderErrorMessage err = alpacaErrorMessage err

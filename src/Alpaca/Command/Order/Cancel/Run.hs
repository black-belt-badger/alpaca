module Alpaca.Command.Order.Cancel.Run
  ( runOrderCancel
  , runOrderCancelWith
  , cancelErrorMessage
  ) where

import Alpaca.Client (AlpacaError (..), alpacaErrorMessage, fetchCancelOrder)
import Alpaca.Command.Order (OrderCancelCommand (..))
import Alpaca.Command.Order.Cancel (renderCancelAccepted, renderCancelPreview)
import Alpaca.Credentials (credentialErrorMessage, loadCredentials)
import System.Exit (die)

-- | Testable effect boundary: the callback is never evaluated in dry run.
-- Exactly one callback invocation occurs when --confirm is present. No retries
-- or polling are performed on a potentially uncertain request outcome.
runOrderCancelWith
  :: (OrderCancelCommand -> IO (Either String ()))
  -> OrderCancelCommand
  -> IO (Either String String)
runOrderCancelWith send options
  | not (cancelConfirmed options) = pure (Right (renderCancelPreview options))
  | otherwise = do
      result <- send options
      pure (renderCancelAccepted options <$ result)

runOrderCancel :: OrderCancelCommand -> IO ()
runOrderCancel options = do
  result <- runOrderCancelWith send options
  either die putStr result
  where
    send command = do
      credentials <- loadCredentials
      case credentials of
        Left err -> pure (Left (credentialErrorMessage err))
        Right creds -> do
          result <- fetchCancelOrder creds command
          pure (either (Left . cancelErrorMessage) Right result)

-- | Never include provider error bodies, headers, order details or secrets.
cancelErrorMessage :: AlpacaError -> String
cancelErrorMessage (UnexpectedStatus 404) =
  "Alpaca paper order not found (HTTP 404)."
cancelErrorMessage (UnexpectedStatus 422) =
  "Alpaca rejected cancellation: order is not cancelable (HTTP 422)."
cancelErrorMessage err = alpacaErrorMessage err

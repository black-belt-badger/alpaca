{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Order.Submit.Run
  ( runSubmit
  , decodeSubmitResult
  , submitErrorMessage
  , dryRunMessage
  ) where

import Alpaca.Client (AlpacaError (..), fetchSubmitOrder)
import Alpaca.Command.Order.Submit
  ( SubmitCommand (..), PreparedOrder, prepareOrder, submittedOrderBody
  , preparedClientIdValue )
import Alpaca.Command.Orders.Run (renderOrderSummary)
import Alpaca.Credentials (credentialErrorMessage, loadCredentials)
import Alpaca.Domain.Order (Order (..), decodeOrder)
import Alpaca.Output (savePrivateJson)
import Control.Exception (IOException, displayException, try)
import Data.ByteString (ByteString)
import qualified Data.Text.IO as TextIO
import qualified Data.ByteString.Lazy.Char8 as Lazy
import System.Exit (die)

dryRunMessage :: PreparedOrder -> String
dryRunMessage prepared =
  "DRY RUN — no credentials loaded; no order submitted.\n"
    <> "Review the intended paper order below; use --confirm to submit.\n"
    <> "A reused client_order_id does not guarantee exactly-once delivery.\n"
    <> Lazy.unpack (submittedOrderBody prepared) <> "\n"

runSubmit :: SubmitCommand -> IO ()
runSubmit options = do
  prepared <- either die pure (prepareOrder options)
  if not (submitConfirmed options)
    then putStr (dryRunMessage prepared)
    else do
      credentials <- loadCredentials >>= either (die . credentialErrorMessage) pure
      response <- fetchSubmitOrder credentials prepared
      (order, raw) <- either die pure (decodeSubmitResult prepared response)
      case submitOutput options of
        Nothing -> do
          putStrLn "Paper order submission returned a response; this does NOT confirm a fill."
          TextIO.putStr (renderOrderSummary order)
        Just path -> do
          saved <- try (savePrivateJson path raw) :: IO (Either IOException ())
          case saved of
            Left err -> die ("Could not save submitted order JSON: " <> displayException err)
            Right () -> do
              putStrLn "Paper submission response received; fill is NOT guaranteed."
              putStrLn ("Saved complete response JSON privately to " <> path)

-- | A successful POST must return an order with the requested client ID.
-- Never treat an arbitrary provider JSON object as a verified submission.
-- The provider response body and JSON parser error never appear in diagnostics.
decodeSubmitResult
  :: PreparedOrder -> Either AlpacaError ByteString -> Either String (Order, ByteString)
decodeSubmitResult prepared result =
  case result of
    Left err -> Left (submitErrorMessage err)
    Right raw ->
      case decodeOrder raw of
        Left _ -> Left "Invalid paper-order submission response. Check paper orders before retrying."
        Right order
          | orderClientOrderId order == Just (preparedClientIdValue prepared) ->
              Right (order, raw)
          | otherwise ->
              Left "Submission response client_order_id does not match. Check paper orders before retrying."

-- | POST is not idempotent. A transport failure or 5xx may have occurred
-- after Alpaca accepted an order. In that case do NOT automatically retry.
submitErrorMessage :: AlpacaError -> String
submitErrorMessage ConnectionFailed =
  "Paper order submission result unknown (network failure). Check existing paper orders by client_order_id before retrying."
submitErrorMessage (UnexpectedStatus 401) =
  "Alpaca paper API rejected credentials (HTTP 401). No response body exposed."
submitErrorMessage (UnexpectedStatus 403) =
  "Alpaca paper order rejected (HTTP 403; check permissions or buying power)."
submitErrorMessage (UnexpectedStatus 422) =
  "Alpaca paper order rejected (HTTP 422; check order parameters and asset rules)."
submitErrorMessage (UnexpectedStatus 429) =
  "Alpaca paper API rate-limited submission (HTTP 429). Check paper orders before retrying."
submitErrorMessage (UnexpectedStatus code)
  | code >= 500 =
      "Alpaca paper API returned HTTP " <> show code
        <> " during submission. Check paper orders before retrying."
  | otherwise =
      "Alpaca paper order submission returned HTTP " <> show code <> "."

{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Account.Run
  ( runAccount
  , renderAccountSummary
  , renderAccountFindings
  , prepareAccountOutput
  , writeAccountBytes
  , saveAccountJson
  ) where

import Alpaca.Client (alpacaErrorMessage, fetchAccount)
import Alpaca.Cli.Output (renderCliFindings, writeCliBytes)
import Alpaca.Command.Account (AccountCommand (..), AccountFormat (..))
import Alpaca.Credentials (credentialErrorMessage, loadCredentials)
import Alpaca.Diagnostics (Finding)
import Alpaca.Diagnostics.Account (accountFindings)
import Alpaca.Domain.Account (Account (..), decodeAccount, statusValue)
import Alpaca.Output (savePrivateJson)
import Control.Exception (IOException, displayException, try)
import Control.Monad (when)
import Data.ByteString (ByteString)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import qualified Data.Text.IO as TextIO
import System.Exit (die)
import System.IO (Handle, stderr, stdout)

runAccount :: AccountCommand -> IO ()
runAccount options = do
  credentials <- loadCredentials >>= orDie credentialErrorMessage
  response <- fetchAccount credentials >>= orDie alpacaErrorMessage
  (rendered, findings) <- orDie id (prepareAccountOutput options response)
  delivered <- case accountOutput options of
    Nothing -> writeAccountBytes stdout rendered
    Just path -> do
      result <- try (saveAccountJson path response) :: IO (Either IOException ())
      case result of
        Left err -> die ("Could not save account JSON: " <> displayException err)
        Right () -> writeAccountBytes stdout
          (Encoding.encodeUtf8 ("Saved complete account JSON to " <> Text.pack path <> "\n"))
  when (delivered && accountCheck options) $
    TextIO.hPutStr stderr (renderAccountFindings findings)

-- | Keep JSON as the original validated provider bytes, not a JSON re-encoding.
-- Diagnostics are separate and never get mixed into the stdout payload.
prepareAccountOutput :: AccountCommand -> ByteString -> Either String (ByteString, [Finding])
prepareAccountOutput options response = do
  account <- either (const (Left "Invalid Alpaca account response.")) Right (decodeAccount response)
  let payload = case accountFormat options of
        AccountText -> Encoding.encodeUtf8 (renderAccountSummary account)
        AccountJson -> response
      findings = if accountCheck options then accountFindings account else []
  Right (payload, findings)

-- | Compatibility aliases; common Unix handling now serves account and positions.
renderAccountFindings :: [Finding] -> Text
renderAccountFindings = renderCliFindings

writeAccountBytes :: Handle -> ByteString -> IO Bool
writeAccountBytes = writeCliBytes

orDie :: (e -> String) -> Either e a -> IO a
orDie render = either (die . render) pure

renderAccountSummary :: Account -> Text
renderAccountSummary account =
  Text.unlines
    [ "Kirke — Alpaca paper account"
    , "Account number: " <> fromMaybe "not provided" (accountNumber account)
    , "Status: " <> statusValue (accountStatus account)
    , "Currency: " <> fromMaybe "not provided" (accountCurrency account)
    , "Cash: " <> fromMaybe "not provided" (accountCash account)
    , "Equity: " <> fromMaybe "not provided" (accountEquity account)
    , "Buying power: " <> fromMaybe "not provided" (accountBuyingPower account)
    , "Trading blocked: " <> maybe "not provided" (\blocked -> if blocked then "yes" else "no") (accountTradingBlocked account)
    , "Crypto status: " <> maybe "not provided" statusValue (accountCryptoStatus account)
    ]

-- | Kept for compatibility with account tests and downstream users.
saveAccountJson :: FilePath -> ByteString -> IO ()
saveAccountJson = savePrivateJson

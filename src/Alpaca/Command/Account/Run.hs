{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Account.Run
  ( runAccount
  , renderAccountSummary
  , saveAccountJson
  ) where

import Alpaca.Client (alpacaErrorMessage, fetchAccount)
import Alpaca.Command.Account (AccountCommand (..))
import Alpaca.Credentials (credentialErrorMessage, loadCredentials)
import Alpaca.Domain.Account (Account (..), decodeAccount)
import Control.Exception (IOException, displayException, onException, try)
import Control.Monad (unless)
import Data.ByteString (ByteString)
import qualified Data.ByteString as ByteString
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import System.Directory (removeFile, renameFile)
import System.Exit (die)
import System.FilePath (takeDirectory)
import System.IO (Handle, hClose, hIsClosed, openBinaryTempFile)
import System.IO.Error (catchIOError)

runAccount :: AccountCommand -> IO ()
runAccount options = do
  credentials <- loadCredentials >>= orDie credentialErrorMessage
  response <- fetchAccount credentials >>= orDie alpacaErrorMessage
  account <- orDie ("Invalid Alpaca account response: " <>) (decodeAccount response)
  case accountOutput options of
    Nothing -> TextIO.putStr (renderAccountSummary account)
    Just path -> do
      result <- try (saveAccountJson path response) :: IO (Either IOException ())
      case result of
        Left err -> die ("Could not save account JSON: " <> displayException err)
        Right () -> putStrLn ("Saved complete account JSON to " <> path)

orDie :: (e -> String) -> Either e a -> IO a
orDie render = either (die . render) pure

renderAccountSummary :: Account -> Text
renderAccountSummary account =
  Text.unlines
    [ "Alpaca paper account"
    , "Account number: " <> accountNumber account
    , "Status: " <> accountStatus account
    , "Currency: " <> accountCurrency account
    , "Cash: " <> accountCash account
    , "Equity: " <> accountEquity account
    , "Buying power: " <> accountBuyingPower account
    , "Trading blocked: " <> if accountTradingBlocked account then "yes" else "no"
    , "Crypto status: " <> fromMaybe "not provided" (accountCryptoStatus account)
    ]

-- | Write to a private temporary file, then replace the destination atomically.
-- openBinaryTempFile creates files with owner-only permissions on Unix.
saveAccountJson :: FilePath -> ByteString -> IO ()
saveAccountJson path bytes = do
  (temporary, handle) <- openBinaryTempFile (takeDirectory path) ".alpaca-account-"
  let cleanup = cleanupTemporary temporary handle
  (ByteString.hPut handle bytes >> hClose handle >> renameFile temporary path)
    `onException` cleanup

cleanupTemporary :: FilePath -> Handle -> IO ()
cleanupTemporary temporary handle = do
  closed <- hIsClosed handle
  unless closed (hClose handle)
  removeFile temporary `catchIOError` const (pure ())

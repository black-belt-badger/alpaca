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
import Alpaca.Output (savePrivateJson)
import Control.Exception (IOException, displayException, try)
import Data.ByteString (ByteString)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import System.Exit (die)

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
    [ "Kirke — Alpaca paper account"
    , "Account number: " <> accountNumber account
    , "Status: " <> accountStatus account
    , "Currency: " <> accountCurrency account
    , "Cash: " <> accountCash account
    , "Equity: " <> accountEquity account
    , "Buying power: " <> accountBuyingPower account
    , "Trading blocked: " <> if accountTradingBlocked account then "yes" else "no"
    , "Crypto status: " <> fromMaybe "not provided" (accountCryptoStatus account)
    ]

-- | Kept for compatibility with account tests and downstream users.
saveAccountJson :: FilePath -> ByteString -> IO ()
saveAccountJson = savePrivateJson

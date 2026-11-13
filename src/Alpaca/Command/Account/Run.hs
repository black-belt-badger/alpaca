{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Account.Run
  ( runAccount
  , renderAccountSummary
  , saveAccountJson
  ) where

import Alpaca.Client (alpacaErrorMessage, fetchAccount)
import Alpaca.Command.Account (AccountCommand (..))
import Alpaca.Credentials (credentialErrorMessage, loadCredentials)
import Alpaca.Domain.Account (Account (..), decodeAccount, statusValue)
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

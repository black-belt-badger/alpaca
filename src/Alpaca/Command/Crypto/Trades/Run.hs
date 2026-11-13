{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Crypto.Trades.Run
  ( runCryptoTrades
  , fetchTradesPagesWith
  , TradesSummary (..)
  , renderTradesSummary
  , writeTradesOutput
  ) where

import Alpaca.Client (AlpacaError, fetchCryptoTradesPage)
import Alpaca.Command.Crypto.Bars
  ( BarsFormat (..)
  , validateDateRange
  )
import Alpaca.Command.Crypto.Bars.Run (marketDataErrorMessage)
import Alpaca.Command.Crypto.Trades (CryptoTradesCommand (..))
import Alpaca.Credentials (credentialErrorMessage, loadCredentials)
import Alpaca.Domain.Crypto.Trade
  ( CryptoTradesPage (..)
  , decodeCryptoTradesPage
  , forEachTrade
  , tradeCount
  , tradeToJson
  )
import Alpaca.Output (withPrivateOutput)
import Control.Exception (IOException, displayException, try)
import Control.Monad (when)
import Data.Aeson (encode)
import Data.ByteString (ByteString)
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Lazy as Lazy
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import System.Exit (die)
import System.IO (Handle, stdout)

-- | The accumulator is small: counts, page count, and a continuation token.
-- The full historical trade stream is never retained between pages.
data TradesSummary = TradesSummary
  { summaryPages :: !Int
  , summaryTrades :: !Int
  , summarySymbols :: !(Map Text Int)
  , summaryNextToken :: !(Maybe Text)
  }
  deriving (Eq, Show)

emptySummary :: TradesSummary
emptySummary = TradesSummary 0 0 Map.empty Nothing

addPage :: TradesSummary -> CryptoTradesPage -> TradesSummary
addPage summary page =
  TradesSummary
    { summaryPages = summaryPages summary + 1
    , summaryTrades = summaryTrades summary + tradeCount page
    , summarySymbols = Map.unionWith (+) (summarySymbols summary)
        (Map.map length (pageTrades page))
    , summaryNextToken = pageNextToken page
    }

-- | Callback consumes each page and releases it before requesting the next.
-- A failed later page returns Left; withPrivateOutput discards partial files.
-- When the output is stdout JSONL, already-written lines cannot be retracted.
fetchTradesPagesWith
  :: (Maybe Text -> IO (Either AlpacaError ByteString))
  -> Int
  -> Maybe Text
  -> (Int -> CryptoTradesPage -> IO ())
  -> IO (Either String TradesSummary)
fetchTradesPagesWith fetch maximumPages initialToken consume
  | maximumPages < 1 || maximumPages > 20 =
      pure (Left "Maximum pages must be between 1 and 20")
  | otherwise = loop maximumPages initialToken Set.empty emptySummary
  where
    loop remaining token seen !summary
      | maybe False (`Set.member` seen) token =
          pure (Left "Alpaca crypto trades returned a repeated page token")
      | otherwise = do
          fetched <- fetch token
          case fetched of
            Left err -> pure (Left (marketDataErrorMessage err))
            Right body ->
              case decodeCryptoTradesPage body of
                Left _ -> pure (Left "Invalid Alpaca crypto trades response.")
                Right page -> do
                  consume (summaryPages summary) page
                  let !nextSummary = addPage summary page
                  case (remaining, pageNextToken page) of
                    (1, _) -> pure (Right nextSummary)
                    (_, Nothing) -> pure (Right nextSummary)
                    (_, Just nextToken) ->
                      loop (remaining - 1) (Just nextToken)
                        (maybe seen (`Set.insert` seen) token) nextSummary

renderTradesSummary :: TradesSummary -> Text
renderTradesSummary summary =
  Text.unlines $
    [ "Kirke — Alpaca historical crypto trades"
    , "Pages: " <> Text.pack (show (summaryPages summary))
    , "Trades: " <> Text.pack (show (summaryTrades summary))
    ]
    <> symbolLines
    <> ["More pages available: " <>
        if maybe False (const True) (summaryNextToken summary) then "yes" else "no"]
  where
    symbolLines
      | Map.null (summarySymbols summary) = ["No matching trades."]
      | otherwise = [symbol <> ": " <> Text.pack (show n)
          | (symbol, n) <- Map.toAscList (summarySymbols summary)]

writePageJsonl :: Handle -> CryptoTradesPage -> IO ()
writePageJsonl handle =
  forEachTrade (\symbol trade ->
    Lazy.hPut handle (encode (tradeToJson symbol trade) <> "\n"))

-- | JSON is a collection of complete provider pages, with the last token
-- available for resumption. No page list is held in memory.
writeTradesOutput
  :: (Maybe Text -> IO (Either AlpacaError ByteString))
  -> CryptoTradesCommand
  -> Handle
  -> IO (Either String TradesSummary)
writeTradesOutput fetch options handle = do
  when (cryptoTradesFormat options == BarsJson) $
    ByteString.hPut handle "{\"pages\":["
  result <- fetchTradesPagesWith fetch
    (cryptoTradesMaxPages options) (cryptoTradesPageToken options)
    (\index page ->
      case cryptoTradesFormat options of
        BarsJson -> do
          when (index > 0) (ByteString.hPut handle ",")
          Lazy.hPut handle (encode (pageOriginal page))
        BarsJsonl -> writePageJsonl handle page)
  case result of
    Left err -> pure (Left err)
    Right summary -> do
      when (cryptoTradesFormat options == BarsJson) $ do
        ByteString.hPut handle "],\"next_page_token\":"
        Lazy.hPut handle (encode (summaryNextToken summary))
        ByteString.hPut handle "}"
      pure (Right summary)

runCryptoTrades :: CryptoTradesCommand -> IO ()
runCryptoTrades options = do
  either die pure (validateDateRange (cryptoTradesStart options) (cryptoTradesEnd options))
  credentials <- loadCredentials >>= either (die . credentialErrorMessage) pure
  let fetch = fetchCryptoTradesPage credentials options
  case cryptoTradesOutput options of
    Just path -> do
      outcome <- try (withPrivateOutput path (writeTradesOutput fetch options))
        :: IO (Either IOException (Either String TradesSummary))
      case outcome of
        Left err -> die ("Could not save crypto trades: " <> displayException err)
        Right (Left err) -> die err
        Right (Right summary) ->
          putStrLn ("Saved " <> show (summaryTrades summary) <> " crypto trades in "
            <> show (summaryPages summary) <> " page(s) to " <> path)
    Nothing ->
      case cryptoTradesFormat options of
        BarsJson -> do
          result <- fetchTradesPagesWith fetch
            (cryptoTradesMaxPages options) (cryptoTradesPageToken options)
            (\_ _ -> pure ())
          either die (TextIO.putStr . renderTradesSummary) result
        BarsJsonl -> do
          result <- fetchTradesPagesWith fetch
            (cryptoTradesMaxPages options) (cryptoTradesPageToken options)
            (\_ -> writePageJsonl stdout)
          either die (const (pure ())) result

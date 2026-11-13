{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Crypto.Quotes.Run
  ( runCryptoQuotes
  , fetchQuotesPagesWith
  , QuotesSummary (..)
  , renderQuotesSummary
  , writeQuotesOutput
  ) where

import Alpaca.Client (AlpacaError, fetchCryptoQuotesPage)
import Alpaca.Command.Crypto.Bars
  ( BarsFormat (..)
  , validateDateRange
  )
import Alpaca.Command.Crypto.Bars.Run (marketDataErrorMessage)
import Alpaca.Command.Crypto.Quotes (CryptoQuotesCommand (..))
import Alpaca.Credentials (credentialErrorMessage, loadCredentials)
import Alpaca.Domain.Crypto.Quote
  ( CryptoQuotesPage (..)
  , decodeCryptoQuotesPage
  , forEachQuote
  , quoteCount
  , quoteToJson
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
-- The full historical quote stream is never retained between pages.
data QuotesSummary = QuotesSummary
  { summaryPages :: !Int
  , summaryQuotes :: !Int
  , summarySymbols :: !(Map Text Int)
  , summaryNextToken :: !(Maybe Text)
  }
  deriving (Eq, Show)

emptySummary :: QuotesSummary
emptySummary = QuotesSummary 0 0 Map.empty Nothing

addPage :: QuotesSummary -> CryptoQuotesPage -> QuotesSummary
addPage summary page =
  QuotesSummary
    { summaryPages = summaryPages summary + 1
    , summaryQuotes = summaryQuotes summary + quoteCount page
    , summarySymbols = Map.unionWith (+) (summarySymbols summary)
        (Map.map length (pageQuotes page))
    , summaryNextToken = pageNextToken page
    }

-- | Callback consumes each page and releases it before requesting the next.
-- A failed later page returns Left; withPrivateOutput discards partial files.
-- When the output is stdout JSONL, already-written lines cannot be retracted.
fetchQuotesPagesWith
  :: (Maybe Text -> IO (Either AlpacaError ByteString))
  -> Int
  -> Maybe Text
  -> (Int -> CryptoQuotesPage -> IO ())
  -> IO (Either String QuotesSummary)
fetchQuotesPagesWith fetch maximumPages initialToken consume
  | maximumPages < 1 || maximumPages > 20 =
      pure (Left "Maximum pages must be between 1 and 20")
  | otherwise = loop maximumPages initialToken Set.empty emptySummary
  where
    loop remaining token seen !summary
      | maybe False (`Set.member` seen) token =
          pure (Left "Alpaca crypto quotes returned a repeated page token")
      | otherwise = do
          fetched <- fetch token
          case fetched of
            Left err -> pure (Left (marketDataErrorMessage err))
            Right body ->
              case decodeCryptoQuotesPage body of
                Left _ -> pure (Left "Invalid Alpaca crypto quotes response.")
                Right page -> do
                  consume (summaryPages summary) page
                  let !nextSummary = addPage summary page
                  case (remaining, pageNextToken page) of
                    (1, _) -> pure (Right nextSummary)
                    (_, Nothing) -> pure (Right nextSummary)
                    (_, Just nextToken) ->
                      loop (remaining - 1) (Just nextToken)
                        (maybe seen (`Set.insert` seen) token) nextSummary

renderQuotesSummary :: QuotesSummary -> Text
renderQuotesSummary summary =
  Text.unlines $
    [ "Kirke — Alpaca historical crypto quotes"
    , "Pages: " <> Text.pack (show (summaryPages summary))
    , "Quotes: " <> Text.pack (show (summaryQuotes summary))
    ]
    <> symbolLines
    <> ["More pages available: " <>
        if maybe False (const True) (summaryNextToken summary) then "yes" else "no"]
  where
    symbolLines
      | Map.null (summarySymbols summary) = ["No matching quotes."]
      | otherwise = [symbol <> ": " <> Text.pack (show n)
          | (symbol, n) <- Map.toAscList (summarySymbols summary)]

writePageJsonl :: Handle -> CryptoQuotesPage -> IO ()
writePageJsonl handle =
  forEachQuote (\symbol quote ->
    Lazy.hPut handle (encode (quoteToJson symbol quote) <> "\n"))

-- | JSON is a collection of complete provider pages, with the last token
-- available for resumption. No page list is held in memory.
writeQuotesOutput
  :: (Maybe Text -> IO (Either AlpacaError ByteString))
  -> CryptoQuotesCommand
  -> Handle
  -> IO (Either String QuotesSummary)
writeQuotesOutput fetch options handle = do
  when (cryptoQuotesFormat options == BarsJson) $
    ByteString.hPut handle "{\"pages\":["
  result <- fetchQuotesPagesWith fetch
    (cryptoQuotesMaxPages options) (cryptoQuotesPageToken options)
    (\index page ->
      case cryptoQuotesFormat options of
        BarsJson -> do
          when (index > 0) (ByteString.hPut handle ",")
          Lazy.hPut handle (encode (pageOriginal page))
        BarsJsonl -> writePageJsonl handle page)
  case result of
    Left err -> pure (Left err)
    Right summary -> do
      when (cryptoQuotesFormat options == BarsJson) $ do
        ByteString.hPut handle "],\"next_page_token\":"
        Lazy.hPut handle (encode (summaryNextToken summary))
        ByteString.hPut handle "}"
      pure (Right summary)

runCryptoQuotes :: CryptoQuotesCommand -> IO ()
runCryptoQuotes options = do
  either die pure (validateDateRange (cryptoQuotesStart options) (cryptoQuotesEnd options))
  credentials <- loadCredentials >>= either (die . credentialErrorMessage) pure
  let fetch = fetchCryptoQuotesPage credentials options
  case cryptoQuotesOutput options of
    Just path -> do
      outcome <- try (withPrivateOutput path (writeQuotesOutput fetch options))
        :: IO (Either IOException (Either String QuotesSummary))
      case outcome of
        Left err -> die ("Could not save crypto quotes: " <> displayException err)
        Right (Left err) -> die err
        Right (Right summary) ->
          putStrLn ("Saved " <> show (summaryQuotes summary) <> " crypto quotes in "
            <> show (summaryPages summary) <> " page(s) to " <> path)
    Nothing ->
      case cryptoQuotesFormat options of
        BarsJson -> do
          result <- fetchQuotesPagesWith fetch
            (cryptoQuotesMaxPages options) (cryptoQuotesPageToken options)
            (\_ _ -> pure ())
          either die (TextIO.putStr . renderQuotesSummary) result
        BarsJsonl -> do
          result <- fetchQuotesPagesWith fetch
            (cryptoQuotesMaxPages options) (cryptoQuotesPageToken options)
            (\_ -> writePageJsonl stdout)
          either die (const (pure ())) result

{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Crypto.Bars.Run
  ( runCryptoBars
  , fetchBarsPagesWith
  , renderBarsSummary
  , marketDataErrorMessage
  ) where

import Alpaca.Client (AlpacaError (..), fetchCryptoBarsPage)
import Alpaca.Command.Crypto.Bars
  ( BarsFormat (..)
  , CryptoBarsCommand (..)
  , validateDateRange
  )
import Alpaca.Credentials (credentialErrorMessage, loadCredentials)
import Alpaca.Domain.Crypto.Bar
  ( CryptoBarsPage (..)
  , barCount
  , decodeCryptoBarsPage
  , encodeBarsJsonl
  , encodePagesJson
  , flattenBars
  )
import Alpaca.Output (savePrivateJson)
import Control.Exception (IOException, displayException, try)
import Data.ByteString (ByteString)
import qualified Data.ByteString as ByteString
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import System.Exit (die)

runCryptoBars :: CryptoBarsCommand -> IO ()
runCryptoBars options = do
  either die pure (validateDateRange (cryptoBarsStart options) (cryptoBarsEnd options))
  credentials <- loadCredentials >>= either (die . credentialErrorMessage) pure
  result <- fetchBarsPagesWith
    (fetchCryptoBarsPage credentials options)
    (cryptoBarsMaxPages options)
    (cryptoBarsPageToken options)
  pages <- either die pure result
  let content = case cryptoBarsFormat options of
        BarsJson -> encodePagesJson pages
        BarsJsonl -> encodeBarsJsonl pages
  case cryptoBarsOutput options of
    Just path -> do
      saved <- try (savePrivateJson path content) :: IO (Either IOException ())
      case saved of
        Left err -> die ("Could not save crypto bars: " <> displayException err)
        Right () -> putStrLn ("Saved " <> show (barCount pages) <> " crypto bars in "
          <> show (length pages) <> " page(s) to " <> path)
    Nothing ->
      case cryptoBarsFormat options of
        BarsJson -> TextIO.putStr (renderBarsSummary pages)
        BarsJsonl -> ByteString.putStr content

-- | Injectable transport permits deterministic offline tests of page bounds,
-- continuing tokens, malformed responses, and duplicate-token protection.
-- No partial output is written when any requested page fails.
fetchBarsPagesWith
  :: (Maybe Text -> IO (Either AlpacaError ByteString))
  -> Int -> Maybe Text -> IO (Either String [CryptoBarsPage])
fetchBarsPagesWith fetch maximumPages initialToken
  | maximumPages < 1 = pure (Left "Maximum pages must be positive")
  | otherwise = loop maximumPages initialToken Set.empty []
  where
    loop remaining token seen pages
      | maybe False (`Set.member` seen) token =
          pure (Left "Alpaca crypto bars returned a repeated page token")
      | otherwise = do
          fetched <- fetch token
          case fetched of
            Left err -> pure (Left (marketDataErrorMessage err))
            Right body ->
              case decodeCryptoBarsPage body of
                Left err -> pure (Left ("Invalid Alpaca crypto bars response: " <> err))
                Right page ->
                  case (remaining, pageNextToken page) of
                    (1, _) -> pure (Right (reverse (page : pages)))
                    (_, Nothing) -> pure (Right (reverse (page : pages)))
                    (_, Just nextToken) ->
                      loop (remaining - 1) (Just nextToken)
                        (maybe seen (`Set.insert` seen) token) (page : pages)

marketDataErrorMessage :: AlpacaError -> String
marketDataErrorMessage ConnectionFailed =
  "Could not connect to Alpaca's market data API. Check your network connection."
marketDataErrorMessage (UnexpectedStatus 401) =
  "Alpaca market data API rejected the credentials (HTTP 401)."
marketDataErrorMessage (UnexpectedStatus 429) =
  "Alpaca market data API rate limited the request (HTTP 429)."
marketDataErrorMessage (UnexpectedStatus status) =
  "Alpaca market data API returned HTTP " <> show status <> "."

renderBarsSummary :: [CryptoBarsPage] -> Text
renderBarsSummary pages =
  Text.unlines $
    [ "Kirke — Alpaca historical crypto bars"
    , "Pages: " <> Text.pack (show (length pages))
    , "Bars: " <> Text.pack (show (barCount pages))
    ]
    <> symbolLines
    <> ["More pages available: " <> if hasMore then "yes" else "no"]
  where
    counts = Map.fromListWith (+) [(symbol, 1 :: Int) | (symbol, _) <- flattenBars pages]
    symbolLines
      | Map.null counts = ["No matching bars."]
      | otherwise = [symbol <> ": " <> Text.pack (show n) | (symbol, n) <- Map.toAscList counts]
    hasMore = case reverse pages of
      [] -> False
      (page : _) -> case pageNextToken page of
        Nothing -> False
        Just _ -> True

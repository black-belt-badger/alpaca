{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Crypto.Quotes.RunSpec (spec) where

import Alpaca.Client (AlpacaError (..))
import Alpaca.Command.Crypto.Bars
  ( BarsFormat (..)
  , BarsSort (..)
  , CryptoLocation (..)
  )
import Alpaca.Command.Crypto.Quotes (CryptoQuotesCommand (..))
import Alpaca.Command.Crypto.Quotes.Run
  ( QuotesSummary (..)
  , fetchQuotesPagesWith
  , renderQuotesSummary
  , writeQuotesOutput
  )
import Alpaca.Output (withPrivateOutput)
import Control.Exception (finally)
import Data.Aeson (Value, eitherDecodeStrict')
import Data.ByteString (ByteString)
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Char8 as Char8
import Data.IORef (modifyIORef', newIORef, readIORef)
import Data.Text (Text)
import qualified Data.Text as Text
import System.Directory (getTemporaryDirectory, removeFile)
import System.IO (hClose, openBinaryTempFile)
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

firstPage :: ByteString
firstPage =
  "{\"quotes\":{\"BTC/USD\":[{\"ap\":29000.123456789012345678,\"as\":0.000000000000123456789,"
  <> "\"bp\":28999.987654321012345678,\"bs\":3.000000000000000001,"
  <> "\"t\":\"2026-10-02T00:00:00.123456789Z\",\"future_quote_metadata\":true}]},"
  <> "\"next_page_token\":\"token-2\",\"future_page_metadata\":42}"

secondPage :: ByteString
secondPage =
  "{\"quotes\":{\"ETH/USD\":[{\"ap\":2200.5,\"as\":0.2,\"bp\":2200.4,\"bs\":0.3,"
  <> "\"t\":\"2026-10-02T00:00:00.234567891Z\"}]},"
  <> "\"next_page_token\":null}"

testOptions :: BarsFormat -> CryptoQuotesCommand
testOptions format =
  CryptoQuotesCommand
    ["BTC/USD", "ETH/USD"] Us Nothing Nothing 2 BarsAsc 2 Nothing format Nothing

-- | Use a real destination without introducing new dependencies.
withDestination :: (FilePath -> IO a) -> IO a
withDestination action = do
  directory <- getTemporaryDirectory
  (path, handle) <- openBinaryTempFile directory "kirke-crypto-quotes-test-"
  hClose handle
  action path `finally` removeFile path

spec :: Spec
spec = do
  it "defaults to one page and exposes a continuation token" $ do
    requested <- newIORef ([] :: [Maybe Text])
    consumed <- newIORef (0 :: Int)
    let fetch token = modifyIORef' requested (<> [token]) >> pure (Right firstPage)
        consume _ _ = modifyIORef' consumed (+1)
    result <- fetchQuotesPagesWith fetch 1 Nothing consume
    fmap summaryQuotes result `shouldBe` Right 1
    fmap summaryPages result `shouldBe` Right 1
    fmap summaryNextToken result `shouldBe` Right (Just "token-2")
    readIORef requested >>= (`shouldBe` [Nothing])
    readIORef consumed >>= (`shouldBe` 1)

  it "follows two pages, preserves their order, and aggregates counts" $ do
    requested <- newIORef ([] :: [Maybe Text])
    indices <- newIORef ([] :: [Int])
    let fetch token = do
          modifyIORef' requested (<> [token])
          pure $ case token of
            Nothing -> Right firstPage
            Just "token-2" -> Right secondPage
            _ -> Left (UnexpectedStatus 400)
        consume index _ = modifyIORef' indices (<> [index])
    result <- fetchQuotesPagesWith fetch 5 Nothing consume
    fmap summaryQuotes result `shouldBe` Right 2
    fmap summaryPages result `shouldBe` Right 2
    fmap summaryNextToken result `shouldBe` Right Nothing
    case result of
      Right summary -> do
        renderQuotesSummary summary `shouldSatisfy` Text.isInfixOf "BTC/USD: 1"
        renderQuotesSummary summary `shouldSatisfy` Text.isInfixOf "ETH/USD: 1"
        renderQuotesSummary summary `shouldSatisfy` Text.isInfixOf "More pages available: no"
      Left err -> error err
    readIORef requested >>= (`shouldBe` [Nothing, Just "token-2"])
    readIORef indices >>= (`shouldBe` [0, 1])

  it "supports a supplied opaque initial page token" $ do
    tokens <- newIORef ([] :: [Maybe Text])
    let fetch token = modifyIORef' tokens (<> [token]) >> pure (Right secondPage)
    result <- fetchQuotesPagesWith fetch 1 (Just "ABC+/==") (\_ _ -> pure ())
    fmap summaryQuotes result `shouldBe` Right 1
    readIORef tokens >>= (`shouldBe` [Just "ABC+/=="])

  it "stops on repeated page tokens rather than looping" $ do
    calls <- newIORef (0 :: Int)
    let fetch _ = modifyIORef' calls (+1) >>
          pure (Right "{\"quotes\":{},\"next_page_token\":\"repeat\"}")
    result <- fetchQuotesPagesWith fetch 20 Nothing (\_ _ -> pure ())
    result `shouldBe` Left "Alpaca crypto quotes returned a repeated page token"
    readIORef calls >>= (`shouldBe` 2)

  it "rejects out-of-range max pages without sending any requests" $ do
    calls <- newIORef (0 :: Int)
    let fetch _ = modifyIORef' calls (+1) >> pure (Right firstPage)
    fetchQuotesPagesWith fetch 0 Nothing (\_ _ -> pure ()) `shouldReturnLeft`
      "Maximum pages must be between 1 and 20"
    fetchQuotesPagesWith fetch 21 Nothing (\_ _ -> pure ()) `shouldReturnLeft`
      "Maximum pages must be between 1 and 20"
    readIORef calls >>= (`shouldBe` 0)

  it "reports malformed later response without fetching a third page" $ do
    calls <- newIORef (0 :: Int)
    let fetch token = do
          modifyIORef' calls (+1)
          pure (Right (if token == Nothing then firstPage else "{\"quotes\":[]}" ))
    result <- fetchQuotesPagesWith fetch 3 Nothing (\_ _ -> pure ())
    result `shouldBe` Left "Invalid Alpaca crypto quotes response."
    readIORef calls >>= (`shouldBe` 2)

  it "reports sanitized credentials and rate-limit errors" $ do
    let fetch _ = pure (Left (UnexpectedStatus 429))
    result <- fetchQuotesPagesWith fetch 2 Nothing (\_ _ -> pure ())
    result `shouldBe` Left "Alpaca market data API rate limited the request (HTTP 429)."
    result401 <- fetchQuotesPagesWith (\_ -> pure (Left (UnexpectedStatus 401))) 1 Nothing (\_ _ -> pure ())
    result401 `shouldBe` Left "Alpaca market data API rejected the credentials (HTTP 401)."
    result503 <- fetchQuotesPagesWith (\_ -> pure (Left (UnexpectedStatus 503))) 1 Nothing (\_ _ -> pure ())
    result503 `shouldBe` Left "Alpaca market data API returned HTTP 503."
    disconnected <- fetchQuotesPagesWith (\_ -> pure (Left ConnectionFailed)) 1 Nothing (\_ _ -> pure ())
    disconnected `shouldBe` Left
      "Could not connect to Alpaca's market data API. Check your network connection."

  it "renders an empty quote history" $ do
    result <- fetchQuotesPagesWith
      (\_ -> pure (Right "{\"quotes\":{},\"next_page_token\":null}"))
      1 Nothing (\_ _ -> pure ())
    fmap renderQuotesSummary result `shouldBe` Right
      "Kirke — Alpaca historical crypto quotes\nPages: 1\nQuotes: 0\nNo matching quotes.\nMore pages available: no\n"

  it "streams multi-page JSON envelope preserving unknown provider fields" $
    withDestination $ \path -> do
      let fetch token = pure (Right (if token == Nothing then firstPage else secondPage))
      result <- withPrivateOutput path
        (writeQuotesOutput fetch (testOptions BarsJson))
      fmap summaryQuotes result `shouldBe` Right 2
      saved <- ByteString.readFile path
      case eitherDecodeStrict' saved :: Either String Value of
        Left err -> error err
        Right output -> do
          let expected = "{\"pages\":[" <> firstPage <> "," <> secondPage <>
                "],\"next_page_token\":null}"
          output `shouldBe` either error id (eitherDecodeStrict' expected)
      saved `shouldSatisfy` Char8.isInfixOf "29000.123456789012345678"

  it "streams JSONL records without storing the full result" $
    withDestination $ \path -> do
      let fetch token = pure (Right (if token == Nothing then firstPage else secondPage))
      result <- withPrivateOutput path (writeQuotesOutput fetch (testOptions BarsJsonl))
      fmap summaryQuotes result `shouldBe` Right 2
      saved <- ByteString.readFile path
      let records = Char8.lines saved
      length records `shouldBe` 2
      saved `shouldSatisfy` Char8.isInfixOf "\"symbol\":\"BTC/USD\""
      saved `shouldSatisfy` Char8.isInfixOf "\"symbol\":\"ETH/USD\""
      saved `shouldSatisfy` Char8.isInfixOf "\"t\":\"2026-10-02T00:00:00.123456789Z\""
      saved `shouldSatisfy` Char8.isInfixOf "29000.123456789012345678"
      mapM_ (\record ->
        (eitherDecodeStrict' record :: Either String Value) `shouldSatisfy` isRight)
        records

  it "rolls back a failed second page without replacing an existing file" $
    withDestination $ \path -> do
      ByteString.writeFile path "existing data"
      let fetch token = pure (Right (if token == Nothing then firstPage else "{\"quotes\":[]}"))
      result <- withPrivateOutput path (writeQuotesOutput fetch (testOptions BarsJsonl))
      result `shouldBe` Left "Invalid Alpaca crypto quotes response."
      ByteString.readFile path >>= (`shouldBe` "existing data")

-- | Allow expressive assertions without throwing on malformed input.
isRight :: Either a b -> Bool
isRight (Right _) = True
isRight _ = False

shouldReturnLeft :: (Eq a, Show a) => IO (Either a b) -> a -> IO ()
shouldReturnLeft action expected = do
  result <- action
  case result of
    Left err -> err `shouldBe` expected
    Right _ -> error "Expected a Left result"

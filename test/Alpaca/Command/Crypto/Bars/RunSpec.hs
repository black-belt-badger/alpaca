{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Crypto.Bars.RunSpec (spec) where

import Alpaca.Client (AlpacaError (..))
import Alpaca.Command.Crypto.Bars.Run
  ( fetchBarsPagesWith
  , marketDataErrorMessage
  , renderBarsSummary
  )
import Alpaca.Domain.Crypto.Bar
  ( decodeCryptoBarsPage
  , encodePagesJson
  , barCount
  )
import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as Char8
import Data.IORef (modifyIORef', newIORef, readIORef)
import Data.Text (Text)
import qualified Data.Text as Text
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

firstPage :: ByteString
firstPage = "{\"bars\":{\"BTC/USD\":[{\"t\":\"2026-10-01T00:00:00.123456789Z\",\"o\":1,\"h\":2,\"l\":1,\"c\":2,\"v\":0.001,\"n\":1,\"vw\":1.5}]},\"next_page_token\":\"token-2\"}"

secondPage :: ByteString
secondPage = "{\"bars\":{\"ETH/USD\":[{\"t\":\"2026-10-01T01:00:00Z\",\"o\":3,\"h\":4,\"l\":3,\"c\":4,\"v\":0.002,\"n\":2,\"vw\":3.5}]},\"next_page_token\":null}"

spec :: Spec
spec = do
  it "defaults to one page even if the provider returns more" $ do
    requests <- newIORef ([] :: [Maybe Text])
    let fetch token = do
          modifyIORef' requests (<> [token])
          pure (Right firstPage)
    result <- fetchBarsPagesWith fetch 1 Nothing
    fmap barCount result `shouldBe` Right 1
    readIORef requests >>= (`shouldBe` [Nothing])
    case result of
      Right pages -> do
        renderBarsSummary pages `shouldSatisfy` Text.isInfixOf "More pages available: yes"
        encodePagesJson pages `shouldSatisfy` Char8.isInfixOf "token-2"
      Left err -> error err

  it "follows a token only with an explicit larger page bound" $ do
    requests <- newIORef ([] :: [Maybe Text])
    let fetch token = do
          modifyIORef' requests (<> [token])
          pure $ case token of
            Nothing -> Right firstPage
            Just "token-2" -> Right secondPage
            _ -> Left (UnexpectedStatus 400)
    result <- fetchBarsPagesWith fetch 5 Nothing
    fmap barCount result `shouldBe` Right 2
    readIORef requests >>= (`shouldBe` [Nothing, Just "token-2"])
    case result of
      Right pages -> do
        renderBarsSummary pages `shouldSatisfy` Text.isInfixOf "BTC/USD: 1"
        renderBarsSummary pages `shouldSatisfy` Text.isInfixOf "ETH/USD: 1"
        renderBarsSummary pages `shouldSatisfy` Text.isInfixOf "More pages available: no"
      Left err -> error err

  it "supports a caller-supplied initial pagination token" $ do
    requests <- newIORef ([] :: [Maybe Text])
    let fetch token = modifyIORef' requests (<> [token]) >> pure (Right secondPage)
    result <- fetchBarsPagesWith fetch 1 (Just "resume")
    fmap barCount result `shouldBe` Right 1
    readIORef requests >>= (`shouldBe` [Just "resume"])

  it "rejects repeated continuation tokens before looping indefinitely" $ do
    requests <- newIORef (0 :: Int)
    let loopPage = "{\"bars\":{},\"next_page_token\":\"repeat\"}"
        fetch _ = modifyIORef' requests (+1) >> pure (Right loopPage)
    result <- fetchBarsPagesWith fetch 20 Nothing
    result `shouldBe` Left "Alpaca crypto bars returned a repeated page token"
    readIORef requests >>= (`shouldBe` 2)

  it "never sends requests for an invalid nonpositive max-pages value" $ do
    requests <- newIORef (0 :: Int)
    let fetch _ = modifyIORef' requests (+1) >> pure (Right firstPage)
    result <- fetchBarsPagesWith fetch 0 Nothing
    result `shouldBe` Left "Maximum pages must be positive"
    readIORef requests >>= (`shouldBe` 0)

  it "rejects malformed responses without continuing or writing partial data" $ do
    requests <- newIORef (0 :: Int)
    let fetch token = do
          modifyIORef' requests (+1)
          pure (Right (if token == Nothing then firstPage else "{\"bars\":[]}"))
    result <- fetchBarsPagesWith fetch 3 Nothing
    case result of
      Left err -> err `shouldSatisfy` (Text.isPrefixOf "Invalid Alpaca crypto bars response:" . Text.pack)
      Right _ -> error "Invalid page must fail"
    readIORef requests >>= (`shouldBe` 2)

  it "renders empty results clearly" $ do
    let page = either error id (decodeCryptoBarsPage "{\"bars\":{},\"next_page_token\":null}")
    renderBarsSummary [page] `shouldBe`
      "Kirke — Alpaca historical crypto bars\nPages: 1\nBars: 0\nNo matching bars.\nMore pages available: no\n"

  it "reports sanitized auth, rate-limit, provider, and transport errors" $ do
    marketDataErrorMessage (UnexpectedStatus 401) `shouldBe`
      "Alpaca market data API rejected the credentials (HTTP 401)."
    marketDataErrorMessage (UnexpectedStatus 429) `shouldBe`
      "Alpaca market data API rate limited the request (HTTP 429)."
    marketDataErrorMessage (UnexpectedStatus 503) `shouldBe`
      "Alpaca market data API returned HTTP 503."
    marketDataErrorMessage ConnectionFailed `shouldBe`
      "Could not connect to Alpaca's market data API. Check your network connection."

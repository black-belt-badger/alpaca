{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Order.AcceptanceSpec (spec) where

import Alpaca.Client (AlpacaError (..))
import Alpaca.Command.Order (OrderId, parseOrderId)
import Alpaca.Command.Order.Run (presentOrderGet)
import Control.Exception (finally)
import Data.Bits ((.&.))
import qualified Data.ByteString as Bytes
import qualified Data.Text as Text
import Paths_kirke (getDataFileName)
import System.Directory (getTemporaryDirectory, removeFile)
import System.FilePath ((</>))
import System.IO (hClose, openBinaryTempFile)
import System.Posix.Files (fileMode, getFileStatus, setFileMode)
import Test.Hspec (Spec, describe, it, shouldBe, shouldSatisfy)

orderId :: String -> OrderId
orderId = either error id . parseOrderId

equityId :: OrderId
equityId = orderId "11111111-2222-4333-8444-555555555555"

cryptoId :: OrderId
cryptoId = orderId "22222222-3333-4444-8555-666666666666"

mlegId :: OrderId
mlegId = orderId "55555555-6666-4777-8888-999999999999"

fixture :: String -> IO Bytes.ByteString
fixture name =
  getDataFileName ("test/fixtures/orders/" <> name) >>= Bytes.readFile

withDestination :: (FilePath -> IO ()) -> IO ()
withDestination action = do
  directory <- getTemporaryDirectory
  (path, handle) <- openBinaryTempFile directory "kirke-order-get-acceptance-"
  hClose handle
  action path `finally` removeFile path

spec :: Spec
spec = describe "GET /v2/orders/{order_id} offline acceptance" $ do
  it "renders the same exact-decimal equity and crypto summaries as list-orders" $ do
    equity <- fixture "order-equity.json"
    equitySummary <- presentOrderGet equityId Nothing (Right equity)
    equitySummary `shouldSatisfy` either (const False) (Text.isInfixOf "  Quantity: 5.123456789012345678901\n")
    equitySummary `shouldSatisfy` either (const False) (Text.isInfixOf "  Filled quantity: 2.000000000000000001\n")
    crypto <- fixture "order-crypto.json"
    cryptoSummary <- presentOrderGet cryptoId Nothing (Right crypto)
    cryptoSummary `shouldSatisfy` either (const False) (Text.isInfixOf "  Notional: 25.1234567890123456789012345\n")

  it "renders nested option legs using the same shared order codec" $ do
    response <- fixture "order-mleg.json"
    output <- presentOrderGet mlegId Nothing (Right response)
    output `shouldSatisfy` either (const False) (Text.isInfixOf "  Legs: 2\n")
    output `shouldSatisfy` either (const False) (Text.isInfixOf "ratio 1.000000000000000001")
    output `shouldSatisfy` either (const False) (Text.isInfixOf "ratio 2.000000000000000002")

  it "exports the original provider bytes, even unknown fields and long decimals, with private permissions" $
    withDestination $ \path -> do
      response <- fixture "order-equity.json"
      setFileMode path 0o644
      result <- presentOrderGet equityId (Just path) (Right response)
      result `shouldBe` Right ("Saved complete order JSON to " <> Text.pack path <> "\n")
      saved <- Bytes.readFile path
      saved `shouldBe` response
      saved `shouldSatisfy` Bytes.isInfixOf "provider_future_decimal"
      file <- getFileStatus path
      fileMode file .&. 0o777 `shouldBe` 0o600

  it "rejects missing, malformed and mismatching IDs without replacing a prior private export" $
    withDestination $ \path -> do
      Bytes.writeFile path "prior-private-order"
      different <- fixture "order-crypto.json"
      mapM_
        (\result -> do
          message <- presentOrderGet equityId (Just path) result
          message `shouldSatisfy` either (const True) (const False)
          saved <- Bytes.readFile path
          saved `shouldBe` "prior-private-order"
        )
        [ Left (UnexpectedStatus 404)
        , Left (UnexpectedStatus 401)
        , Left (UnexpectedStatus 429)
        , Left ConnectionFailed
        , Right different
        , Right "{}"
        , Right "[]"
        , Right "{\"id\":\"11111111-2222-4333-8444-555555555555\",\"status\":true}"
        ]

  it "reports distinct sanitized errors for missing, inaccessible and unrelated orders" $ do
    missing <- presentOrderGet equityId Nothing (Left (UnexpectedStatus 404))
    missing `shouldBe` Left "Alpaca paper order not found (HTTP 404)."
    auth <- presentOrderGet equityId Nothing (Left (UnexpectedStatus 401))
    auth `shouldBe` Left "Alpaca paper API rejected the credentials (HTTP 401)."
    unrelated <- fixture "order-crypto.json"
    mismatch <- presentOrderGet equityId Nothing (Right unrelated)
    mismatch `shouldBe` Left "Invalid Alpaca order response: order ID does not match requested UUID."

  it "never echoes an order body if private export fails" $
    withDestination $ \path -> do
      response <- fixture "order-equity.json"
      result <- presentOrderGet equityId (Just (path </> "order.json")) (Right response)
      result `shouldSatisfy` either (const True) (const False)
      result `shouldSatisfy` either (not . Text.isInfixOf "SYNTHETIC-EQUITY-ORDER-1" . Text.pack) (const False)

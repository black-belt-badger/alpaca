{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Orders.AcceptanceSpec (spec) where

import Alpaca.Command.Orders.Run (presentOrders)
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

-- Use the same six synthetic order responses as Medea's acceptance test.
-- No paper account credentials or provider network traffic are necessary.
sharedOrders :: IO Bytes.ByteString
sharedOrders = getDataFileName "test/fixtures/orders/orders-mixed.json" >>= Bytes.readFile

withDestination :: (FilePath -> IO ()) -> IO ()
withDestination action = do
  directory <- getTemporaryDirectory
  (path, handle) <- openBinaryTempFile directory "kirke-orders-acceptance-"
  hClose handle
  action path `finally` removeFile path

spec :: Spec
spec = describe "GET /v2/orders command acceptance" $ do
  it "renders six synthetic equity, crypto, bracket and multi-leg orders without rounding" $ do
    response <- sharedOrders
    result <- presentOrders Nothing response
    result `shouldSatisfy` either (const False) (Text.isInfixOf "Orders: 6\n")
    result `shouldSatisfy` either (const False) (Text.isInfixOf "  Quantity: 5.123456789012345678901\n")
    result `shouldSatisfy` either (const False) (Text.isInfixOf "  Filled quantity: 2.000000000000000001\n")
    result `shouldSatisfy` either (const False) (Text.isInfixOf "  Notional: 25.1234567890123456789012345\n")
    result `shouldSatisfy` either (const False) (Text.isInfixOf "  Legs: 2\n")

  it "accepts the empty order array and its empty raw export" $ do
    summary <- presentOrders Nothing "[]"
    summary `shouldBe` Right "Kirke — Alpaca paper orders\nNo matching orders.\n"
    withDestination $ \path -> do
      message <- presentOrders (Just path) "[]"
      message `shouldBe` Right ("Saved complete orders JSON to " <> Text.pack path <> "\n")
      actual <- Bytes.readFile path
      actual `shouldBe` "[]"

  it "exports the complete original JSON including unknown fields and exact decimals privately" $
    withDestination $ \path -> do
      response <- sharedOrders
      setFileMode path 0o644
      message <- presentOrders (Just path) response
      message `shouldBe` Right ("Saved complete orders JSON to " <> Text.pack path <> "\n")
      actual <- Bytes.readFile path
      actual `shouldBe` response
      status <- getFileStatus path
      fileMode status .&. 0o777 `shouldBe` 0o600

  it "validates every order in the array before overwriting existing export" $
    withDestination $ \path -> do
      Bytes.writeFile path "previous-good-data"
      let invalid =
            [ ""
            , "null"
            , "{}"
            , "[null]"
            , "[{}]"
            , "[{"
            , "[{\"id\":\"order-one\",\"status\":\"filled\"},{\"id\":\"missing-status\"}]"
            , "[{\"id\":\"order-one\",\"status\":\"filled\"},{\"id\":\"other\",\"status\":\"filled\",\"qty\":3.14}]"
            ]
      mapM_
        (\body -> do
          result <- presentOrders (Just path) body
          result `shouldBe` Left "Invalid Alpaca orders response."
          existing <- Bytes.readFile path
          existing `shouldBe` "previous-good-data"
        )
        invalid

  it "does not echo provider data when a JSON export fails" $
    withDestination $ \path -> do
      response <- sharedOrders
      result <- presentOrders (Just (path </> "orders.json")) response
      result `shouldSatisfy` either (const True) (const False)
      result `shouldSatisfy` either (not . Text.isInfixOf "SYNTHETIC-EQUITY-ORDER-1" . Text.pack) (const False)

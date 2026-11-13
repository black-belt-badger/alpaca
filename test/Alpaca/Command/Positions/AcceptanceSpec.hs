{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Positions.AcceptanceSpec (spec) where

import Alpaca.Command.Positions.Run (presentPositions)
import Control.Exception (finally)
import Data.Bits ((.&.))
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Char8 as Char8
import qualified Data.Text as Text
import System.Directory (getTemporaryDirectory, removeFile)
import System.FilePath ((</>))
import System.IO (hClose, openBinaryTempFile)
import System.Posix.Files (fileMode, getFileStatus, setFileMode)
import Test.Hspec (Spec, describe, it, shouldBe, shouldSatisfy)

-- Synthetic fixture deliberately shares the market-data/portfolio semantics
-- exercised by Medea: exact decimals, two distinct statuses and future fields.
positionBytes :: ByteString.ByteString
positionBytes =
  Char8.pack
    "[{\"asset_class\":\"crypto\",\"asset_id\":\"private-position-id\",\"asset_marginable\":false,\"avg_entry_price\":\"67123.0000000000000000000001\",\"change_today\":\"0\",\"cost_basis\":\"68.00123456789012345678\",\"current_price\":\"67291.12\",\"exchange\":\"CRYPTO\",\"lastday_price\":\"66500.50\",\"market_value\":\"67.123456789012345\",\"qty\":\"0.000997498123456789012345\",\"side\":\"long\",\"symbol\":\"BTCUSD\",\"unrealized_intraday_pl\":\"0\",\"unrealized_intraday_plpc\":\"0\",\"unrealized_pl\":\"-0.000000000001\",\"unrealized_plpc\":\"-0.0000000000123456789\",\"qty_available\":null,\"future_provider_property\":{\"decimal\":\"1.00000000000000000000001\"}}]"

withTemporaryDestination :: (FilePath -> IO ()) -> IO ()
withTemporaryDestination action = do
  directory <- getTemporaryDirectory
  (path, handle) <- openBinaryTempFile directory "kirke-position-acceptance-"
  hClose handle
  action path `finally` removeFile path

spec :: Spec
spec = describe "GET /v2/positions offline acceptance" $ do
  it "preserves precision, skips private IDs and supports the empty portfolio" $ do
    result <- presentPositions Nothing positionBytes
    result `shouldSatisfy` either (const False) (Text.isInfixOf "  Quantity: 0.000997498123456789012345\n")
    result `shouldSatisfy` either (const False) (Text.isInfixOf "  Market value: 67.123456789012345\n")
    result `shouldSatisfy` either (const False) (Text.isInfixOf "  Unrealized P/L: -0.000000000001\n")
    result `shouldSatisfy` either (const False) (not . Text.isInfixOf "private-position-id")
    empty <- presentPositions Nothing "[]"
    empty `shouldBe` Right "Kirke — Alpaca paper positions\nNo open positions.\n"

  it "exports unchanged bytes and replaces a public file with owner-only permissions" $
    withTemporaryDestination $ \path -> do
      setFileMode path 0o644
      result <- presentPositions (Just path) positionBytes
      result `shouldBe` Right ("Saved complete positions JSON to " <> Text.pack path <> "\n")
      saved <- ByteString.readFile path
      saved `shouldBe` positionBytes
      status <- getFileStatus path
      fileMode status .&. 0o777 `shouldBe` 0o600

  it "never overwrites an existing export when the provider data is invalid" $
    withTemporaryDestination $ \path -> do
      ByteString.writeFile path "original-private-data"
      mapM_
        (\invalid -> do
          result <- presentPositions (Just path) invalid
          result `shouldBe` Left "Invalid Alpaca positions response."
          saved <- ByteString.readFile path
          saved `shouldBe` "original-private-data"
        )
        ["", "null", "{}", "[null]", "[{}]", "[{", "[{\"asset_class\":\"crypto\"}]"]

  it "reports an unwritable destination without leaking the provider response" $
    withTemporaryDestination $ \path -> do
      result <- presentPositions (Just (path </> "position.json")) positionBytes
      result `shouldSatisfy` either (const True) (const False)
      result `shouldSatisfy` either (not . Text.isInfixOf "private-position-id" . Text.pack) (const False)

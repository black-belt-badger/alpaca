{-# LANGUAGE OverloadedStrings #-}

module Alpaca.OutputSpec (spec) where

import Alpaca.Output (savePrivateJson)
import Control.Exception (finally)
import Data.Bits ((.&.))
import qualified Data.ByteString as ByteString
import System.Directory (getTemporaryDirectory, removeFile)
import System.IO (hClose, openBinaryTempFile)
import System.Posix.Files (fileMode, getFileStatus, setFileMode)
import Test.Hspec (Spec, it, shouldBe)

spec :: Spec
spec =
  it "atomically replaces a public file with exact owner-only JSON" $ do
    directory <- getTemporaryDirectory
    (path, handle) <- openBinaryTempFile directory "kirke-positions-test-"
    hClose handle
    let json = "[{\"symbol\":\"BTCUSD\",\"provider_field\":true}]"
    ( do
        setFileMode path 0o644
        savePrivateJson path json
        saved <- ByteString.readFile path
        saved `shouldBe` json
        status <- getFileStatus path
        fileMode status .&. 0o777 `shouldBe` 0o600
      )
      `finally` removeFile path

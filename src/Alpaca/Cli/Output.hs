{-# LANGUAGE OverloadedStrings #-}

-- | CLI-only presentation and stdout handling shared across endpoints.
-- Domain models and provider clients do not know about terminals.
module Alpaca.Cli.Output
  ( renderCliFindings
  , writeCliBytes
  ) where

import Alpaca.Diagnostics (Finding (..), severityValue)
import Control.Exception (IOException, catch)
import Data.ByteString (ByteString)
import qualified Data.ByteString as Bytes
import Data.Text (Text)
import qualified Data.Text as Text
import System.Exit (die)
import System.IO (Handle, hFlush)
import System.IO.Error (isResourceVanishedError)

renderCliFindings :: [Finding] -> Text
renderCliFindings = Text.concat . map render
  where
    render finding =
      Text.toUpper (severityValue (findingSeverity finding))
        <> " " <> findingCode finding <> " (" <> findingPath finding <> "): "
        <> findingMessage finding <> "\n"

-- | A downstream consumer closing a pipe is not an upstream failure.
-- Other I/O errors remain unsuccessful and are reported without response data.
writeCliBytes :: Handle -> ByteString -> IO Bool
writeCliBytes handle bytes =
  (Bytes.hPut handle bytes >> hFlush handle >> pure True) `catch` handleWriteError
  where
    handleWriteError :: IOException -> IO Bool
    handleWriteError err
      | isResourceVanishedError err = pure False
      | otherwise = die "Could not write CLI output."

module Alpaca.Output (savePrivateJson) where

import Control.Exception (onException)
import Control.Monad (unless)
import Data.ByteString (ByteString)
import qualified Data.ByteString as ByteString
import System.Directory (removeFile, renameFile)
import System.FilePath (takeDirectory)
import System.IO (Handle, hClose, hIsClosed, openBinaryTempFile)
import System.IO.Error (catchIOError)

-- | Atomically replace the destination using a private file in its directory.
-- openBinaryTempFile uses owner-only permissions on Unix.
savePrivateJson :: FilePath -> ByteString -> IO ()
savePrivateJson path bytes = do
  (temporary, handle) <- openBinaryTempFile (takeDirectory path) ".kirke-json-"
  let cleanup = cleanupTemporary temporary handle
  (ByteString.hPut handle bytes >> hClose handle >> renameFile temporary path)
    `onException` cleanup

cleanupTemporary :: FilePath -> Handle -> IO ()
cleanupTemporary temporary handle = do
  closed <- hIsClosed handle
  unless closed (hClose handle)
  removeFile temporary `catchIOError` const (pure ())

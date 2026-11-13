module Alpaca.Output (savePrivateJson, withPrivateOutput) where

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

-- | Stream data to an owner-only temporary file and rename only on success.
-- A failed API page or callback discards the temporary file, leaving any
-- existing destination untouched. Exceptions also clean up the temporary.
withPrivateOutput :: FilePath -> (Handle -> IO (Either String a)) -> IO (Either String a)
withPrivateOutput path write = do
  (temporary, handle) <- openBinaryTempFile (takeDirectory path) ".kirke-json-"
  let cleanup = cleanupTemporary temporary handle
  result <- write handle `onException` cleanup
  case result of
    Left err -> cleanup >> pure (Left err)
    Right value -> do
      (hClose handle >> renameFile temporary path) `onException` cleanup
      pure (Right value)

cleanupTemporary :: FilePath -> Handle -> IO ()
cleanupTemporary temporary handle = do
  closed <- hIsClosed handle
  unless closed (hClose handle)
  removeFile temporary `catchIOError` const (pure ())

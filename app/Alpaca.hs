module Main (main) where

import Command (Command (..))
import CommandParser (commandParserInfo)
import Credentials (credentialErrorMessage, loadCredentials)
import Options.Applicative (execParser)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

main :: IO ()
main = do
  command <- execParser commandParserInfo
  case command of
    Account _ -> do
      result <- loadCredentials
      case result of
        Left err -> do
          hPutStrLn stderr (credentialErrorMessage err)
          exitFailure
        Right _ -> do
          print command
          hPutStrLn stderr "Credentials loaded; account fetching is not implemented yet."

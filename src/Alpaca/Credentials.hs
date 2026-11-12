module Alpaca.Credentials
  ( Credentials (..)
  , CredentialError (..)
  , loadCredentials
  , validateCredentials
  , credentialErrorMessage
  ) where

import Data.Char (isSpace)
import Data.Text (Text)
import qualified Data.Text as Text
import System.Environment (lookupEnv)

-- | Alpaca API credentials. Deliberately no Show instance.
data Credentials = Credentials
  { apiKeyId :: Text
  , apiSecretKey :: Text
  }

data CredentialError
  = MissingEnvironmentVariable String
  | EmptyEnvironmentVariable String
  deriving (Eq, Show)

loadCredentials :: IO (Either CredentialError Credentials)
loadCredentials = do
  key <- lookupEnv "APCA_API_KEY_ID"
  secret <- lookupEnv "APCA_API_SECRET_KEY"
  pure (validateCredentials key secret)

-- | Pure validation, so credentials can be tested without changing the process environment.
validateCredentials :: Maybe String -> Maybe String -> Either CredentialError Credentials
validateCredentials key secret =
  Credentials
    <$> require "APCA_API_KEY_ID" key
    <*> require "APCA_API_SECRET_KEY" secret
  where
    require name Nothing = Left (MissingEnvironmentVariable name)
    require name (Just value)
      | all isSpace value = Left (EmptyEnvironmentVariable name)
      | otherwise = Right (Text.pack value)

credentialErrorMessage :: CredentialError -> String
credentialErrorMessage (MissingEnvironmentVariable name) =
  "Missing environment variable: " <> name
credentialErrorMessage (EmptyEnvironmentVariable name) =
  "Empty environment variable: " <> name

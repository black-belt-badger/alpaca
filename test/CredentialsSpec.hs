{-# LANGUAGE OverloadedStrings #-}

module CredentialsSpec (spec) where

import Credentials
  ( CredentialError (..)
  , Credentials (..)
  , credentialErrorMessage
  , validateCredentials
  )
import Test.Hspec (Spec, expectationFailure, it, shouldBe)

spec :: Spec
spec = do
  it "accepts two nonempty credentials" $
    case validateCredentials (Just "example-key") (Just "example-secret") of
      Right credentials -> do
        apiKeyId credentials `shouldBe` "example-key"
        apiSecretKey credentials `shouldBe` "example-secret"
      Left err -> expectationFailure (credentialErrorMessage err)

  it "rejects a missing API key" $
    credentialError (validateCredentials Nothing (Just "secret"))
      `shouldBe` Just (MissingEnvironmentVariable "APCA_API_KEY_ID")

  it "rejects a missing API secret" $
    credentialError (validateCredentials (Just "key") Nothing)
      `shouldBe` Just (MissingEnvironmentVariable "APCA_API_SECRET_KEY")

  it "rejects an empty API key" $
    credentialError (validateCredentials (Just "") (Just "secret"))
      `shouldBe` Just (EmptyEnvironmentVariable "APCA_API_KEY_ID")

  it "rejects a whitespace-only API secret" $
    credentialError (validateCredentials (Just "key") (Just "  "))
      `shouldBe` Just (EmptyEnvironmentVariable "APCA_API_SECRET_KEY")

credentialError :: Either CredentialError Credentials -> Maybe CredentialError
credentialError (Left err) = Just err
credentialError (Right _) = Nothing

{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import AccountCommand (AccountCommand (..))
import Command (Command (..))
import CommandParser (commandParserInfo)
import Credentials
  ( CredentialError (..)
  , Credentials (..)
  , credentialErrorMessage
  , validateCredentials
  )
import Options.Applicative (defaultPrefs, execParserPure, getParseResult)
import Test.Hspec (describe, expectationFailure, hspec, it, shouldBe)

main :: IO ()
main = hspec $ do
  describe "alpaca command parser" $ do
    it "parses account without an output path" $
      parse ["account"] `shouldBe` Just (Account (AccountCommand Nothing))

    it "parses account with --out" $
      parse ["account", "--out", "account.json"]
        `shouldBe` Just (Account (AccountCommand (Just "account.json")))

    it "rejects --out without a path" $
      parse ["account", "--out"] `shouldBe` Nothing

    it "rejects an unknown option" $
      parse ["account", "--unexpected"] `shouldBe` Nothing

    it "rejects an unknown subcommand" $
      parse ["unknown"] `shouldBe` Nothing

    it "requires a subcommand" $
      parse [] `shouldBe` Nothing

  describe "Alpaca credentials" $ do
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

parse :: [String] -> Maybe Command
parse = getParseResult . execParserPure defaultPrefs commandParserInfo

credentialError :: Either CredentialError Credentials -> Maybe CredentialError
credentialError (Left err) = Just err
credentialError (Right _) = Nothing

module CommandParserSpec (spec) where

import AccountCommand (AccountCommand (..))
import Command (Command (..))
import CommandParser (commandParserInfo)
import Options.Applicative (defaultPrefs, execParserPure, getParseResult)
import Test.Hspec (Spec, it, shouldBe)

spec :: Spec
spec = do
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

parse :: [String] -> Maybe Command
parse = getParseResult . execParserPure defaultPrefs commandParserInfo

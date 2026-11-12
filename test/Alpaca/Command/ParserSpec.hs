module Alpaca.Command.ParserSpec (spec) where

import Alpaca.Command.Account (AccountCommand (..))
import Alpaca.Command.Positions (PositionsCommand (..))
import Alpaca.Command (Command (..))
import Alpaca.Command.Parser (commandParserInfo)
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

  it "parses positions without output" $
    parse ["positions"] `shouldBe` Just (Positions (PositionsCommand Nothing))

  it "parses positions with --out" $
    parse ["positions", "--out", "positions.json"]
      `shouldBe` Just (Positions (PositionsCommand (Just "positions.json")))

  it "rejects positions --out without a path" $
    parse ["positions", "--out"] `shouldBe` Nothing

  it "rejects an unknown positions option" $
    parse ["positions", "--unexpected"] `shouldBe` Nothing

  it "rejects an unknown option" $
    parse ["account", "--unexpected"] `shouldBe` Nothing

  it "rejects an unknown subcommand" $
    parse ["unknown"] `shouldBe` Nothing

  it "requires a subcommand" $
    parse [] `shouldBe` Nothing

parse :: [String] -> Maybe Command
parse = getParseResult . execParserPure defaultPrefs commandParserInfo

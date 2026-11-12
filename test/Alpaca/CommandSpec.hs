module Alpaca.CommandSpec (spec) where

import Alpaca.Command.Account (AccountCommand (..))
import Alpaca.Command (Command (..))
import Test.Hspec (Spec, it, shouldBe)

spec :: Spec
spec = do
  it "wraps account command options" $
    Account (AccountCommand (Just "account.json"))
      `shouldBe` Account (AccountCommand (Just "account.json"))

  it "distinguishes different account command options" $
    (Account (AccountCommand Nothing) == Account (AccountCommand (Just "account.json")))
      `shouldBe` False

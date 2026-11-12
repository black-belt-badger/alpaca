module Alpaca.CommandSpec (spec) where

import Alpaca.Command.Account (AccountCommand (..))
import Alpaca.Command.Positions (PositionsCommand (..))
import Alpaca.Command (Command (..))
import Test.Hspec (Spec, it, shouldBe)

spec :: Spec
spec = do
  it "wraps account command options" $
    Account (AccountCommand (Just "account.json"))
      `shouldBe` Account (AccountCommand (Just "account.json"))

  it "wraps positions command options" $
    Positions (PositionsCommand Nothing)
      `shouldBe` Positions (PositionsCommand Nothing)

  it "distinguishes account and positions" $
    Account (AccountCommand Nothing) == Positions (PositionsCommand Nothing)
      `shouldBe` False

  it "distinguishes different account command options" $
    (Account (AccountCommand Nothing) == Account (AccountCommand (Just "account.json")))
      `shouldBe` False

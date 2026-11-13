module Alpaca.Command.AccountSpec (spec) where

import Alpaca.Command.Account (AccountCommand (..), AccountFormat (..), parseAccountFormat)
import Test.Hspec (Spec, it, shouldBe)

spec :: Spec
spec = do
  it "selects only the two agreed account formats" $ do
    parseAccountFormat "text" `shouldBe` Right AccountText
    parseAccountFormat "json" `shouldBe` Right AccountJson
    parseAccountFormat "jsonl" `shouldBe` Left "Account format must be text or json"
  it "has no output path when omitted" $
    accountOutput (AccountCommand Nothing AccountText False) `shouldBe` Nothing

  it "retains the selected output path" $
    accountOutput (AccountCommand (Just "output/account.json") AccountText False)
      `shouldBe` Just "output/account.json"

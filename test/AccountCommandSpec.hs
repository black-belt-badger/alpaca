module AccountCommandSpec (spec) where

import AccountCommand (AccountCommand (..))
import Test.Hspec (Spec, it, shouldBe)

spec :: Spec
spec = do
  it "has no output path when omitted" $
    accountOutput (AccountCommand Nothing) `shouldBe` Nothing

  it "retains the selected output path" $
    accountOutput (AccountCommand (Just "output/account.json"))
      `shouldBe` Just "output/account.json"

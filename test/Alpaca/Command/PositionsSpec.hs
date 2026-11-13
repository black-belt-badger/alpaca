module Alpaca.Command.PositionsSpec (spec) where

import Alpaca.Command.Positions (PositionsCommand (..), PositionsFormat (..), parsePositionsFormat)
import Test.Hspec (Spec, it, shouldBe)

spec :: Spec
spec = do
  it "accepts only text or exact raw JSON" $ do
    parsePositionsFormat "text" `shouldBe` Right PositionsText
    parsePositionsFormat "json" `shouldBe` Right PositionsJson
    parsePositionsFormat "jsonl" `shouldBe` Left "Positions format must be text or json"
  it "has no output file by default" $
    positionsOutput (PositionsCommand Nothing PositionsText False) `shouldBe` Nothing

  it "retains a JSON output path" $
    positionsOutput (PositionsCommand (Just "positions.json") PositionsText False) `shouldBe` Just "positions.json"

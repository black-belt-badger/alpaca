module Alpaca.Command.PositionsSpec (spec) where

import Alpaca.Command.Positions (PositionsCommand (..))
import Test.Hspec (Spec, it, shouldBe)

spec :: Spec
spec = do
  it "has no output file by default" $
    positionsOutput (PositionsCommand Nothing) `shouldBe` Nothing

  it "retains a JSON output path" $
    positionsOutput (PositionsCommand (Just "positions.json")) `shouldBe` Just "positions.json"

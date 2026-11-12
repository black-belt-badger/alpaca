module Alpaca.Command.OrderSpec (spec) where

import Alpaca.Command.Order (orderIdSegment, parseOrderId)
import Data.Either (isLeft)
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

sampleId :: String
sampleId = "9275f66a-0a1b-4a22-8c55-167416c7cf14"

spec :: Spec
spec = do
  it "accepts a canonical Alpaca UUID" $
    fmap orderIdSegment (parseOrderId sampleId) `shouldBe` Right sampleId

  it "accepts uppercase hexadecimal digits" $
    fmap orderIdSegment (parseOrderId "9275F66A-0A1B-4A22-8C55-167416C7CF14")
      `shouldBe` Right "9275F66A-0A1B-4A22-8C55-167416C7CF14"

  it "rejects empty, abbreviated, malformed or non-UUID IDs" $
    mapM_ (\value -> parseOrderId value `shouldSatisfy` isLeft)
      ["", " ", "not-a-uuid", "1234", "00000000-0000-0000-0000-00000000000",
       "00000000_0000_0000_0000_000000000000",
       "00000000-0000-0000-0000-00000000000g"]

  it "prevents path, query or fragment injection" $
    mapM_ (\value -> parseOrderId value `shouldSatisfy` isLeft)
      ["9275f66a-0a1b-4a22-8c55-167416c7cf14/positions",
       "9275f66a-0a1b-4a22-8c55-167416c7cf14?nested=true",
       "9275f66a-0a1b-4a22-8c55-167416c7cf14#fragment",
       "../v2/account", "9275f66a-0a1b-4a22-8c55-167416c7cf14%2f"]

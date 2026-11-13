{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Command.Positions.UnixSpec (spec) where

import Alpaca.Cli.Output (renderCliFindings)
import Alpaca.Command.Positions (PositionsCommand (..), PositionsFormat (..))
import Alpaca.Command.Positions.AcceptanceSpec (positionBytes)
import Alpaca.Command.Positions.Run (preparePositionsOutput)
import Alpaca.Diagnostics (Finding (..), Severity (..))
import qualified Data.ByteString as Bytes
import qualified Data.ByteString.Char8 as Char8
import qualified Data.Text as Text
import Test.Hspec (Spec, describe, it, shouldBe, shouldSatisfy)

options :: PositionsFormat -> Bool -> PositionsCommand
options format' check = PositionsCommand Nothing format' check

prepared :: PositionsFormat -> Bool -> Bytes.ByteString -> (Bytes.ByteString, [Finding])
prepared format' check = either error id . preparePositionsOutput (options format' check)

spec :: Spec
spec = describe "Positions JSON and diagnostics Unix contract" $ do
  it "retains the default text summary with no findings" $ do
    let (output, findings) = prepared PositionsText False positionBytes
    output `shouldSatisfy` Bytes.isInfixOf "Alpaca paper positions\n"
    output `shouldSatisfy` Bytes.isInfixOf "  Quantity: 0.000997498123456789012345\n"
    findings `shouldBe` []

  it "preserves byte-exact provider JSON and unknown fields with --check" $ do
    let (json, findings) = prepared PositionsJson True positionBytes
    json `shouldBe` positionBytes
    findings `shouldBe` []

  it "reports [] as an informational snapshot without contaminating JSON" $ do
    let (json, findings) = prepared PositionsJson True "[]"
    json `shouldBe` "[]"
    map (\f -> (findingCode f, findingSeverity f, findingPath f)) findings
      `shouldBe` [("POSITIONS_EMPTY", Info, "positions")]
    renderCliFindings findings
      `shouldBe` "INFO POSITIONS_EMPTY (positions): Alpaca returned no open positions.\n"

  it "does not interpret a future position side or reveal its value" $ do
    let future = Char8.pack . Text.unpack $
          Text.replace "\"side\":\"long\"" "\"side\":\"FUTURE_PRIVATE_SIDE\""
            (Text.pack (Char8.unpack positionBytes))
        (json, findings) = prepared PositionsJson True future
    json `shouldBe` future
    map (\f -> (findingCode f, findingSeverity f, findingPath f)) findings
      `shouldBe` [("POSITION_SIDE_UNKNOWN", Warning, "positions[].side")]
    renderCliFindings findings `shouldSatisfy` (not . Text.isInfixOf "FUTURE_PRIVATE_SIDE")
    renderCliFindings findings `shouldSatisfy` (not . Text.isInfixOf "private-position-id")

  it "rejects malformed second position before any data is prepared" $ do
    let malformed = Bytes.init positionBytes <> ",{}]"
    preparePositionsOutput (options PositionsJson True) malformed
      `shouldBe` Left "Invalid Alpaca positions response."

  it "keeps human and JSON formats free of ANSI codes" $ do
    let (json, findings) = prepared PositionsJson True "[]"
    json `shouldSatisfy` (not . Bytes.isInfixOf "\ESC[")
    renderCliFindings findings `shouldSatisfy` (not . Text.isInfixOf "\ESC[")

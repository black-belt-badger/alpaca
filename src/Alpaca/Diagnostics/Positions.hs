{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Diagnostics.Positions (positionsFindings) where

import Alpaca.Diagnostics (Finding (..), Severity (..))
import Alpaca.Domain.Position (Position (..), PositionSide (..))

-- | Report only facts that the provider explicitly establishes.
-- Never interpret negative P/L as a recommendation or imply positions
-- are absent on another account or at another point in time.
positionsFindings :: [Position] -> [Finding]
positionsFindings positions =
  emptyFinding <> unfamiliarSideFinding
  where
    emptyFinding =
      if null positions
        then
          [ Finding
              "POSITIONS_EMPTY"
              Info
              "positions"
              "Alpaca returned no open positions."
              (Just "This describes the fetched paper-account snapshot, not historical holdings.")
          ]
        else []
    unfamiliarSideFinding =
      if any unknownSide positions
        then
          [ Finding
              "POSITION_SIDE_UNKNOWN"
              Warning
              "positions[].side"
              "Alpaca returned a position side not recognized by this client."
              (Just "The raw value is preserved in the JSON response; no meaning is inferred.")
          ]
        else []
    unknownSide position =
      case positionSide position of
        SideOther _ -> True
        _ -> False

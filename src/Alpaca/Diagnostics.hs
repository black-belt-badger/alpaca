{-# LANGUAGE OverloadedStrings #-}

-- | Provider-agnostic, pure diagnostics. No transport, terminal or JSON logic
-- belongs here. The same codes and severities are defined in Medea.
module Alpaca.Diagnostics
  ( Severity (..)
  , severityValue
  , Finding (..)
  ) where

import Data.Text (Text)

data Severity = Info | Warning | Error
  deriving (Eq, Ord, Show)

severityValue :: Severity -> Text
severityValue Info = "info"
severityValue Warning = "warning"
severityValue Error = "error"

-- | Stable diagnostic identity, subject path and factual interpretation.
-- Never store private account identifiers or upstream response bodies here.
data Finding = Finding
  { findingCode :: Text
  , findingSeverity :: Severity
  , findingPath :: Text
  , findingMessage :: Text
  , findingExplanation :: Maybe Text
  }
  deriving (Eq, Show)

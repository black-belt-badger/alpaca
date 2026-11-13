{-# LANGUAGE OverloadedStrings #-}

-- | Account observations independent of HTTP, terminal output and trading.
module Alpaca.Diagnostics.Account (accountFindings) where

import Alpaca.Diagnostics (Finding (..), Severity (..))
import Alpaca.Domain.Account (Account (..), AccountStatus (StatusActive))

accountFindings :: Account -> [Finding]
accountFindings account = statusFindings <> blockedFindings <> cryptoFindings
  where
    statusFindings =
      if accountStatus account == StatusActive
        then []
        else
          [ Finding
              "ACCOUNT_STATUS_NOT_ACTIVE"
              Warning
              "status"
              "Alpaca reports an account status other than ACTIVE."
              (Just "Account status is a distinct provider field; do not infer complete trading permissions from it.")
          ]
    blockedFindings =
      case accountTradingBlocked account of
        Just True ->
          [ Finding
              "ACCOUNT_TRADING_BLOCKED"
              Error
              "trading_blocked"
              "Alpaca reports trading_blocked=true."
              (Just "This restriction is independent of status; an ACTIVE status does not override it.")
          ]
        Just False -> []
        Nothing ->
          [ Finding
              "ACCOUNT_TRADING_BLOCKED_UNKNOWN"
              Info
              "trading_blocked"
              "Alpaca did not provide a trading_blocked value."
              (Just "Absence is not evidence of trading permission.")
          ]
    cryptoFindings =
      case accountCryptoStatus account of
        Just StatusActive -> []
        Just _ ->
          [ Finding
              "ACCOUNT_CRYPTO_STATUS_NOT_ACTIVE"
              Info
              "crypto_status"
              "Alpaca reports a crypto_status other than ACTIVE."
              (Just "This is a separate provider status; its value alone does not establish trading eligibility.")
          ]
        Nothing -> []

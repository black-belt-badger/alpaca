{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Client
  ( AlpacaError (..)
  , fetchAccount
  , fetchPositions
  , positionsRequest
  , interpretPaperResponse
  , accountRequest
  , interpretAccountResponse
  , alpacaErrorMessage
  ) where

import Control.Exception (try)
import Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as Lazy
import Data.Text.Encoding (encodeUtf8)
import Alpaca.Credentials (Credentials (..))
import Network.HTTP.Client
  ( HttpException
  , Request (..)
  , Response
  , httpLbs
  , newManager
  , parseRequest_
  , responseBody
  , responseStatus
  , responseTimeoutMicro
  )
import Network.HTTP.Client.TLS (tlsManagerSettings)
import Network.HTTP.Types.Status (statusCode)

-- | Errors deliberately contain no request headers, credentials, or response body.
data AlpacaError
  = ConnectionFailed
  | UnexpectedStatus Int
  deriving (Eq, Show)

-- | Retrieve the complete, unmodified JSON response from the paper trading API.
fetchAccount :: Credentials -> IO (Either AlpacaError ByteString)
fetchAccount = fetchPaper . accountRequest

-- | Retrieve open positions from the same authenticated paper Trading API.
fetchPositions :: Credentials -> IO (Either AlpacaError ByteString)
fetchPositions = fetchPaper . positionsRequest

fetchPaper :: Request -> IO (Either AlpacaError ByteString)
fetchPaper request = do
  result <-
    try (newManager tlsManagerSettings >>= httpLbs request)
      :: IO (Either HttpException (Response Lazy.ByteString))
  pure $ case result of
    Left _ -> Left ConnectionFailed
    Right response ->
      interpretPaperResponse
        (statusCode (responseStatus response))
        (Lazy.toStrict (responseBody response))

-- | Construct requests without IO, exposing no credentials in diagnostics.
accountRequest :: Credentials -> Request
accountRequest credentials = paperRequest credentials "/v2/account"

positionsRequest :: Credentials -> Request
positionsRequest credentials = paperRequest credentials "/v2/positions"

paperRequest :: Credentials -> String -> Request
paperRequest credentials endpoint =
  (parseRequest_ ("https://paper-api.alpaca.markets" <> endpoint))
    { method = "GET"
    , requestHeaders =
        [ ("APCA-API-KEY-ID", encodeUtf8 (apiKeyId credentials))
        , ("APCA-API-SECRET-KEY", encodeUtf8 (apiSecretKey credentials))
        ]
    , responseTimeout = responseTimeoutMicro (20 * 1000000)
    , redirectCount = 0  -- Never forward authentication headers to a redirect target.
    -- Inspect the HTTP status ourselves, rather than exposing an exception
    -- that may include the request (and therefore its authentication headers).
    , checkResponse = \_ _ -> pure ()
    }

-- | Only successful HTTP responses are accepted.
interpretAccountResponse :: Int -> ByteString -> Either AlpacaError ByteString
interpretAccountResponse = interpretPaperResponse

interpretPaperResponse :: Int -> ByteString -> Either AlpacaError ByteString
interpretPaperResponse status body
  | status >= 200 && status < 300 = Right body
  | otherwise = Left (UnexpectedStatus status)

alpacaErrorMessage :: AlpacaError -> String
alpacaErrorMessage ConnectionFailed =
  "Could not connect to Alpaca's paper API. Check your network connection."
alpacaErrorMessage (UnexpectedStatus 401) =
  "Alpaca paper API rejected the credentials (HTTP 401)."
alpacaErrorMessage (UnexpectedStatus status) =
  "Alpaca paper API returned HTTP " <> show status <> "."

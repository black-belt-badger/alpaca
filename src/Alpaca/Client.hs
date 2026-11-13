{-# LANGUAGE OverloadedStrings #-}

module Alpaca.Client
  ( AlpacaError (..)
  , fetchAccount
  , fetchPositions
  , fetchAssets
  , fetchCryptoBarsPage
  , fetchCryptoTradesPage
  , fetchCryptoQuotesPage
  , cryptoTradesRequest
  , cryptoQuotesRequest
  , cryptoBarsRequest
  , fetchOrders
  , fetchOrder
  , fetchSubmitOrder
  , submitOrderRequest
  , orderRequest
  , ordersRequest
  , assetsRequest
  , positionsRequest
  , interpretPaperResponse
  , accountRequest
  , interpretAccountResponse
  , alpacaErrorMessage
  ) where

import Control.Exception (try)
import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as Char8
import Data.List (intercalate)
import qualified Data.Text as Text
import qualified Data.ByteString.Lazy as Lazy
import Data.Text.Encoding (encodeUtf8)
import Alpaca.Command.Assets
  ( AssetsCommand (..)
  , assetClassParameter
  , assetStatusParameter
  , assetExchangeParameter
  , assetAttributeParameter
  )
import Alpaca.Command.Crypto.Bars
  ( BarsInstant
  , BarsSort
  , CryptoBarsCommand (..)
  , CryptoLocation
  , instantParameter
  , locationParameter
  , sortParameter
  , timeframeParameter
  )
import Alpaca.Command.Crypto.Trades (CryptoTradesCommand (..))
import Alpaca.Command.Crypto.Quotes (CryptoQuotesCommand (..))
import Alpaca.Command.Order (OrderGetCommand (..), orderIdSegment)
import Alpaca.Command.Order.Submit (PreparedOrder, submittedOrderBody)
import Alpaca.Credentials (Credentials (..))
import Alpaca.Command.Orders
  ( OrdersCommand (..), orderStatusParameter, orderDirectionParameter
  , orderSideParameter, orderAssetClassParameter
  )
import Network.HTTP.Client
  ( HttpException
  , Request (..)
  , RequestBody (..)
  , Response
  , httpLbs
  , newManager
  , parseRequest_
  , responseBody
  , responseStatus
  , responseTimeoutMicro
  , setQueryString
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
fetchAccount = fetchAuthenticated . accountRequest

-- | Retrieve open positions from the same authenticated paper Trading API.
fetchPositions :: Credentials -> IO (Either AlpacaError ByteString)
fetchPositions = fetchAuthenticated . positionsRequest

-- | Asset class is explicitly supplied, since Alpaca defaults to equities.
fetchAssets :: Credentials -> AssetsCommand -> IO (Either AlpacaError ByteString)
fetchAssets credentials = fetchAuthenticated . assetsRequest credentials

-- | GET orders is read-only; all query values are typed or CLI-validated.
fetchOrders :: Credentials -> OrdersCommand -> IO (Either AlpacaError ByteString)
fetchOrders credentials = fetchAuthenticated . ordersRequest credentials

-- | Fetch a single paper order by its server-issued UUID.
fetchOrder :: Credentials -> OrderGetCommand -> IO (Either AlpacaError ByteString)
fetchOrder credentials = fetchAuthenticated . orderRequest credentials

-- | A single paper-only POST; no automatic retry, no live-trading host.
fetchSubmitOrder :: Credentials -> PreparedOrder -> IO (Either AlpacaError ByteString)
fetchSubmitOrder credentials = fetchAuthenticated . submitOrderRequest credentials

-- | All endpoints use the same protected HTTPS transport; the URL specifies
-- either the trading (paper) API or the read-only market-data API.
fetchCryptoBarsPage
  :: Credentials -> CryptoBarsCommand -> Maybe Text.Text -> IO (Either AlpacaError ByteString)
fetchCryptoBarsPage credentials options token =
  fetchAuthenticated (cryptoBarsRequest credentials options token)

-- | Read-only historical trades use the same HTTPS transport and credentials.
fetchCryptoTradesPage
  :: Credentials -> CryptoTradesCommand -> Maybe Text.Text -> IO (Either AlpacaError ByteString)
fetchCryptoTradesPage credentials options token =
  fetchAuthenticated (cryptoTradesRequest credentials options token)

-- | Read-only best bid/ask quotes from the same authenticated market API.
fetchCryptoQuotesPage
  :: Credentials -> CryptoQuotesCommand -> Maybe Text.Text -> IO (Either AlpacaError ByteString)
fetchCryptoQuotesPage credentials options token =
  fetchAuthenticated (cryptoQuotesRequest credentials options token)

fetchAuthenticated :: Request -> IO (Either AlpacaError ByteString)
fetchAuthenticated request = do
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

-- | Construct the query with HTTP-client's encoding, never by interpolating
-- untrusted query text into a URL. The filters are typed allowed values.
assetsRequest :: Credentials -> AssetsCommand -> Request
assetsRequest credentials options =
  setQueryString
    ( [("asset_class", Just (assetClassParameter (assetsClass options)))]
        <> maybe [] (\status -> [("status", Just (assetStatusParameter status))]) (assetsStatus options)
        <> maybe [] (\exchanges -> [("exchange", Just (Char8.intercalate "," (map assetExchangeParameter exchanges)))]) (assetsExchanges options)
        <> maybe [] (\attributes -> [("attributes", Just (Char8.intercalate "," (map assetAttributeParameter attributes)))]) (assetsAttributes options)
    )
    (paperRequest credentials "/v2/assets")

ordersRequest :: Credentials -> OrdersCommand -> Request
ordersRequest credentials options =
  setQueryString
    ( [("status", Just (orderStatusParameter (ordersStatus options)))]
        <> maybe [] (\n -> [("limit", Just (Char8.pack (show n)))]) (ordersLimit options)
        <> maybe [] (\symbols -> [("symbols", Just (Char8.pack (intercalate "," symbols)))]) (ordersSymbols options)
        <> [("direction", Just (orderDirectionParameter (ordersDirection options)))]
        <> maybe [] (\v -> [("after", Just (encodeUtf8 (instantParameter v)))]) (ordersAfter options)
        <> maybe [] (\v -> [("until", Just (encodeUtf8 (instantParameter v)))]) (ordersUntil options)
        <> (if ordersNested options then [("nested", Just "true")] else [])
        <> maybe [] (\v -> [("side", Just (orderSideParameter v))]) (ordersSide options)
        <> maybe [] (\classes -> [("asset_class", Just (Char8.intercalate "," (map orderAssetClassParameter classes)))]) (ordersAssetClasses options)
        <> maybe [] (\ident -> [("before_order_id", Just (Char8.pack (orderIdSegment ident)))]) (ordersBeforeOrderId options)
        <> maybe [] (\ident -> [("after_order_id", Just (Char8.pack (orderIdSegment ident)))]) (ordersAfterOrderId options)
    )
    (paperRequest credentials "/v2/orders")

-- | UUID validation happens in the abstract OrderId constructor. A validated
-- path segment cannot escape /v2/orders or inject query parameters.
orderRequest :: Credentials -> OrderGetCommand -> Request
orderRequest credentials options =
  setQueryString
    (if getOrderNested options then [("nested", Just "true")] else [])
    (paperRequest credentials ("/v2/orders/" <> orderIdSegment (getOrderId options)))

-- | Pure request construction from a validated payload. No redirects or
-- retried non-idempotent requests; responses are checked by the caller.
submitOrderRequest :: Credentials -> PreparedOrder -> Request
submitOrderRequest credentials prepared =
  let base = paperRequest credentials "/v2/orders"
  in base { method = "POST"
          , requestHeaders = ("Content-Type", "application/json") : requestHeaders base
          , requestBody = RequestBodyLBS (submittedOrderBody prepared)
          }

-- | Use allowlisted crypto location and query serialization, never a
-- user-controlled URL; page tokens are opaque and percent-encoded.
-- | Shared historical crypto request: only the allowlisted endpoint and
-- the optional bars timeframe differ between bars and trades.
data CryptoDataQuery = CryptoDataQuery
  { queryEndpoint :: String
  , querySymbols :: [Text.Text]
  , queryLocation :: CryptoLocation
  , queryTimeframe :: Maybe Text.Text
  , queryStart :: Maybe BarsInstant
  , queryEnd :: Maybe BarsInstant
  , queryLimit :: Int
  , querySort :: BarsSort
  , queryToken :: Maybe Text.Text
  }

cryptoBarsRequest :: Credentials -> CryptoBarsCommand -> Maybe Text.Text -> Request
cryptoBarsRequest credentials options token =
  cryptoDataRequest credentials CryptoDataQuery
    { queryEndpoint = "bars"
    , querySymbols = cryptoBarsSymbols options
    , queryLocation = cryptoBarsLocation options
    , queryTimeframe = Just (timeframeParameter (cryptoBarsTimeframe options))
    , queryStart = cryptoBarsStart options
    , queryEnd = cryptoBarsEnd options
    , queryLimit = cryptoBarsLimit options
    , querySort = cryptoBarsSort options
    , queryToken = token
    }

cryptoTradesRequest :: Credentials -> CryptoTradesCommand -> Maybe Text.Text -> Request
cryptoTradesRequest credentials options token =
  cryptoDataRequest credentials CryptoDataQuery
    { queryEndpoint = "trades"
    , querySymbols = cryptoTradesSymbols options
    , queryLocation = cryptoTradesLocation options
    , queryTimeframe = Nothing
    , queryStart = cryptoTradesStart options
    , queryEnd = cryptoTradesEnd options
    , queryLimit = cryptoTradesLimit options
    , querySort = cryptoTradesSort options
    , queryToken = token
    }

cryptoQuotesRequest :: Credentials -> CryptoQuotesCommand -> Maybe Text.Text -> Request
cryptoQuotesRequest credentials options token =
  cryptoDataRequest credentials CryptoDataQuery
    { queryEndpoint = "quotes"
    , querySymbols = cryptoQuotesSymbols options
    , queryLocation = cryptoQuotesLocation options
    , queryTimeframe = Nothing
    , queryStart = cryptoQuotesStart options
    , queryEnd = cryptoQuotesEnd options
    , queryLimit = cryptoQuotesLimit options
    , querySort = cryptoQuotesSort options
    , queryToken = token
    }

cryptoDataRequest :: Credentials -> CryptoDataQuery -> Request
cryptoDataRequest credentials query =
  setQueryString
    ( [("symbols", Just (encodeUtf8 (Text.intercalate "," (querySymbols query))))]
        <> maybe [] (\timeframe -> [("timeframe", Just (encodeUtf8 timeframe))])
          (queryTimeframe query)
        <> maybe [] (\start -> [("start", Just (encodeUtf8 (instantParameter start)))])
          (queryStart query)
        <> maybe [] (\end -> [("end", Just (encodeUtf8 (instantParameter end)))])
          (queryEnd query)
        <> [ ("limit", Just (Char8.pack (show (queryLimit query))))
           , ("sort", Just (encodeUtf8 (sortParameter (querySort query))))
           ]
        <> maybe [] (\token -> [("page_token", Just (encodeUtf8 token))])
          (queryToken query)
    )
    (authenticatedRequest credentials
      ("https://data.alpaca.markets/v1beta3/crypto/" <>
        locationParameter (queryLocation query) <> "/" <> queryEndpoint query))

paperRequest :: Credentials -> String -> Request
paperRequest credentials endpoint =
  authenticatedRequest credentials ("https://paper-api.alpaca.markets" <> endpoint)

authenticatedRequest :: Credentials -> String -> Request
authenticatedRequest credentials url =
  (parseRequest_ url)
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

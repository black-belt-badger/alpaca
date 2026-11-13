module Alpaca.Command.Order.Cancel.RunSpec (spec) where

import Alpaca.Client (AlpacaError (..), interpretCancelResponse)
import Alpaca.Command.Order (OrderCancelCommand (..), OrderId, parseOrderId)
import Alpaca.Command.Order.Cancel (renderCancelAccepted, renderCancelPreview)
import Alpaca.Command.Order.Cancel.Run (runOrderCancelWith, cancelErrorMessage)
import Data.IORef (modifyIORef', newIORef, readIORef)
import Data.List (isInfixOf)
import Test.Hspec (Spec, it, shouldBe, shouldSatisfy)

orderId :: OrderId
orderId = either error id (parseOrderId "9275f66a-0a1b-4a22-8c55-167416c7cf14")

preview :: OrderCancelCommand
preview = OrderCancelCommand orderId False

confirmed :: OrderCancelCommand
confirmed = OrderCancelCommand orderId True

spec :: Spec
spec = do
  it "defaults to an offline dry run and never invokes the callback" $ do
    called <- newIORef (0 :: Int)
    let fake _ = do
          modifyIORef' called (+1)
          pure (Left "should never be called")
    result <- runOrderCancelWith fake preview
    count <- readIORef called
    count `shouldBe` 0
    result `shouldBe` Right (renderCancelPreview preview)
    renderCancelPreview preview `shouldSatisfy` isInfixOf "DRY RUN"
    renderCancelPreview preview `shouldSatisfy` isInfixOf "no cancellation was sent"
    renderCancelPreview preview `shouldSatisfy` isInfixOf "--confirm"

  it "sends exactly one request on confirmation and never claims canceled" $ do
    called <- newIORef (0 :: Int)
    let fake _ = do
          modifyIORef' called (+1)
          pure (Right ())
    result <- runOrderCancelWith fake confirmed
    count <- readIORef called
    count `shouldBe` 1
    result `shouldBe` Right (renderCancelAccepted confirmed)
    renderCancelAccepted confirmed `shouldSatisfy` isInfixOf "HTTP 204"
    renderCancelAccepted confirmed `shouldSatisfy` isInfixOf "not yet confirmed"
    renderCancelAccepted confirmed `shouldSatisfy` isInfixOf "kirke order get"

  it "does not retry uncertain failures or report success for 404/422" $ do
    called <- newIORef (0 :: Int)
    let fake _ = do
          modifyIORef' called (+1)
          pure (Left "Alpaca rejected cancellation")
    result <- runOrderCancelWith fake confirmed
    count <- readIORef called
    count `shouldBe` 1
    result `shouldBe` Left "Alpaca rejected cancellation"

  it "accepts exactly HTTP 204, rejecting other statuses including 200" $ do
    interpretCancelResponse 204 `shouldBe` Right ()
    mapM_ (\status -> interpretCancelResponse status
      `shouldBe` Left (UnexpectedStatus status))
      [200, 201, 202, 206, 301, 400, 401, 403, 404, 409, 422, 429, 500, 503]

  it "distinguishes non-existent and non-cancelable orders" $ do
    cancelErrorMessage (UnexpectedStatus 404)
      `shouldBe` "Alpaca paper order not found (HTTP 404)."
    cancelErrorMessage (UnexpectedStatus 422)
      `shouldBe` "Alpaca rejected cancellation: order is not cancelable (HTTP 422)."

  it "keeps authentication, rate-limit, provider and transport errors sanitized" $ do
    let cases =
          [ (UnexpectedStatus 401, "Alpaca paper API rejected the credentials (HTTP 401).")
          , (UnexpectedStatus 403, "Alpaca paper API returned HTTP 403.")
          , (UnexpectedStatus 429, "Alpaca paper API returned HTTP 429.")
          , (UnexpectedStatus 500, "Alpaca paper API returned HTTP 500.")
          , (ConnectionFailed, "Could not connect to Alpaca's paper API. Check your network connection.")
          ]
    mapM_ (\(failure, expected) -> cancelErrorMessage failure `shouldBe` expected) cases
    mapM_ (\(failure, _) -> do
      let message = cancelErrorMessage failure
      message `shouldSatisfy` (not . isInfixOf "example-secret")
      message `shouldSatisfy` (not . isInfixOf "raw-body")
      ) cases

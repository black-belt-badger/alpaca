module Alpaca.Command.Order.Cancel
  ( renderCancelPreview
  , renderCancelAccepted
  ) where

import Alpaca.Command.Order (OrderCancelCommand (..), orderIdSegment)

-- | Default is a pure dry run; an explicit --confirm is the only way
-- to authorize one DELETE request to the fixed Alpaca PAPER host.
renderCancelPreview :: OrderCancelCommand -> String
renderCancelPreview options =
  "DRY RUN — no cancellation was sent.\n"
    <> "Paper order: " <> orderIdSegment (cancelOrderId options) <> "\n"
    <> "To request cancellation, repeat with --confirm.\n"

-- | HTTP 204 means *accepted*, not necessarily an order in canceled state.
renderCancelAccepted :: OrderCancelCommand -> String
renderCancelAccepted options =
  "Alpaca accepted the paper order cancellation request (HTTP 204).\n"
    <> "Cancellation is not yet confirmed. Check order status with:\n"
    <> "  kirke order get " <> orderIdSegment (cancelOrderId options) <> "\n"

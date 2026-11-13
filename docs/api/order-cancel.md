# Cancel one Alpaca paper order — Kirke

**Endpoint:** `DELETE https://paper-api.alpaca.markets/v2/orders/{order_id}`. This command **can change paper-account state**. It never connects to the live trading host.

This differs from read-only order retrieval, and from the distinct `DELETE /v2/orders` endpoint that attempts to cancel **all** orders. Kirke implements only **one** server-supplied order UUID at a time.

## Usage and safety gate

By default, cancelling an order is an **offline preview**:

```sh
kirke order cancel 9275f66a-0a1b-4a22-8c55-167416c7cf14
```

The output says no request was sent and explains how to opt in. The illustrated UUID is synthetic. Dry run does **not read credentials** or make any HTTP call.

To send one actual paper-account cancellation request, the user must opt in explicitly:

```sh
kirke order cancel ACTUAL_SERVER_ORDER_UUID --confirm
```

**`--confirm` sends a real DELETE to your Alpaca paper account.** This is not a simulation and is never performed automatically by integration tests. It is only for an existing order the operator intends to cancel. The parameter is the provider's `id` field, **not** `client_order_id`. The UUID must be canonical (36 ASCII characters, four hyphens, hexadecimal digits); invalid paths and unrecognized flags fail in the CLI before credentials/network.

No `--all`, `--out`, retries, cancel-by-client-ID, follow-up mutation, or automatic 404 recovery is supported. There is no cancel-all command.

## Request contract and response semantics

| Property | Contract |
| --- | --- |
| Method and host | HTTPS DELETE; **paper-api.alpaca.markets** only |
| Path | `/v2/orders/{order_id}` with a validated opaque canonical UUID |
| Query and request body | Neither |
| Authorization | Same Alpaca paper API headers as the read-only commands, loaded **only after** `--confirm` |
| Transport | 20-second timeout, automatic redirects disabled, no application-level retries |
| Safety default | Dry run; no credentials or network access |
| HTTP 204 | Cancellation **request accepted**, not proof that order status is already `canceled` |
| HTTP 404 | Order not found |
| HTTP 422 | Order is no longer cancelable (for example already filled or expired) |
| HTTP 401 / 403 / 429 / 5xx | Authentication, permission, rate limit or provider error, not silently treated as cancellation |
| Unexpected HTTP 200 / 202 | **Not accepted**; only 204 qualifies |
| Network timeout / failure | Outcome may be uncertain. Do not blindly retry; inspect the order first |

The client does not read or display provider error bodies and never logs keys, secret headers or raw HTTP exceptions. Request construction and the entire status interpreter are testable with synthetic data. A dry run never evaluates the network callback; confirmed mode invokes it exactly once, with no application retries.

**After any HTTP 204, verify final state separately:**

```sh
kirke order get ACTUAL_SERVER_ORDER_UUID
```

A 204 acknowledges cancellation acceptance but does not prove the order has reached the terminal `canceled` state; an order may fill before cancellation takes effect. If the connection drops or another ambiguous outcome occurs, inspect the order first rather than issuing an automatic second DELETE.

## Tests

Offline Hspec tests cover CLI parsing, strict UUID validation, fixed HTTPS paper host, empty query/body, shared auth headers, disabled redirects, 204-only acceptance, distinct 404/422, 401/403/429/5xx/transport errors, exact-once callback for `--confirm`, and the absence of *any* callback in dry run.

`scripts/cd.sh` exercises only the no-credentials dry-run path, with a synthetic UUID and explicit checks of the output. It **never** runs a confirmed DELETE. The GitHub Actions suite uses synthetic values and makes no live calls.

## Triparity

This is the Haskell endpoint [Kirke #21](https://github.com/black-belt-badger/kirke/issues/21). The Rust counterpart is [Medea #15](https://github.com/black-belt-badger/medea/issues/15). Preserve the same opt-in behavior and HTTP interpretation when implementing Medea, and reserve wider CLI UX/diagnostics decisions for the established Atalanta–Kirke–Medea triparity review.

Alpaca reference: [Delete Order by ID](https://docs.alpaca.markets/us/reference/deleteorderbyorderid-1).

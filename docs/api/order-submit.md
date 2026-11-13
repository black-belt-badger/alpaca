# Kirke — Submit a crypto paper order (M5)

Endpoint: `POST https://paper-api.alpaca.markets/v2/orders`. **Paper-account orders only.** No live endpoint, configurable trading host, automatic retries, or order writes outside an explicit `--confirm`.

Scope: [Kirke #20](https://github.com/black-belt-badger/kirke/issues/20); [Alpaca Create Order](https://docs.alpaca.markets/us/reference/postorder); [Alpaca Crypto Orders](https://docs.alpaca.markets/us/docs/crypto-orders). This is deliberately a **limited first paper-order implementation**, not the entire Alpaca order algebra. The corresponding Medea implementation is [#14](https://github.com/black-belt-badger/medea/issues/14) after this contract has been reviewed.

## Safe defaults

```sh
# DRY RUN (default) — prints the exact JSON request, without loading credentials
kirke order submit --symbol BTC/USD --side buy --type market \
  --qty 0.0001 --client-order-id experiment-btc-001

# CRYPTO LIMIT DRY RUN
kirke order submit --symbol BTC/USD --side buy --type limit \
  --qty 0.0001 --limit-price 65000.00 --time-in-force gtc \
  --client-order-id experiment-btc-limit-001

# ACTUAL PAPER SUBMISSION — explicit confirmation required
kirke order submit --symbol BTC/USD --side buy --type market \
  --qty 0.0001 --client-order-id experiment-btc-001 --confirm

# Write the verified paper response as private JSON (never in dry-run mode)
kirke order submit --symbol ETH/USD --side buy --type market \
  --notional 25.12 --client-order-id experiment-eth-001 \
  --confirm --out output/paper-order.json
```

These are examples of command syntax, **not** orders that were submitted. The `--out` destination's parent directory must already exist.

The `--client-order-id` is **always required**, unique for each distinct intended order, and stable across uncertain attempts. The CLI does not generate a random ID; this avoids showing one ID in a dry run and submitting another later. Alpaca may reject duplicate IDs, but **client-order IDs do not guarantee exactly-once execution**. If the HTTP response is lost, inspect existing paper orders before attempting another POST. Never retry automatically.

## Supported request contract

| Parameter | Validation | Serialized form |
|---|---|---|
| `--symbol PAIR` | Exactly one uppercase crypto pair, e.g. `BTC/USD` or `ETH/BTC` | `symbol` JSON string |
| `--side buy\|sell` | Required; two known sides only | `side` string |
| `--type market\|limit` | Required; stop, bracket, options and advanced types are intentionally unavailable | `type` string |
| `--qty DECIMAL` | Positive ASCII decimal; up to 9 fractional digits | `qty` JSON string |
| `--notional DECIMAL` | Positive ASCII decimal, market orders only; up to 2 decimals for USD-quoted crypto, up to 9 for non-USD | `notional` JSON string |
| `--limit-price DECIMAL` | Required for limit, forbidden for market | `limit_price` JSON string |
| `--time-in-force gtc\|ioc` | Default `gtc`; no `day`, `fok`, `opg` or `cls` | `time_in_force` string |
| `--client-order-id ID` | Required, 1–128 safe ASCII characters (letters, digits, `.`, `-`, `_`, `:`) | `client_order_id` string |
| `--confirm` | Absent by default; only presence enables POST after validation | CLI-only flag, **never** sent in body |
| `--out PATH` | Only with `--confirm`; private atomic original response | CLI-only destination |

Exactly **one of `--qty` or `--notional`** is permitted. `--type limit` requires `--qty` and `--limit-price`; `--type market` forbids `--limit-price` and permits either positive quantity or notional. Zero, negative values, exponent notation, malformed strings, excessive decimal precision, invalid IDs and unsafe symbols fail before authentication. Trade size, minimum order increments, eligibility, buying power and market conditions remain subject to Alpaca's provider-side checks.

The produced POST body contains **only these seven optional/required order properties**. It uses `aeson` JSON strings for financial values: no intermediate `Double` conversions, no `Float`, and no hidden defaults for side, quantity or price. The `order_class` is omitted, using Alpaca's simple-order default.

## Execution and failure semantics

| Event | Behavior |
|---|---|
| Dry run (default) | Print `DRY RUN — no credentials loaded; no order submitted` and JSON request; no network request |
| `--confirm` with missing credentials | Fail before network with a specific missing environment variable error |
| `--confirm` with valid credentials | One authenticated POST to paper API using existing 20s timeout and redirect ban |
| Success with matching `client_order_id` | Decode through existing typed `Order` model, display current status or save original full JSON privately |
| Success with malformed order or mismatched ID | Sanitized error with instruction to inspect paper orders; never expose untrusted response or save it |
| 401 | Credentials rejected |
| 403 | Rejected: buying power, shares, or account authorization may be insufficient |
| 422 | Invalid/unsupported provider order or asset-specific rules |
| 429 | Rate-limited; check existing orders before retrying |
| 5xx / network timeout | Outcome may be **unknown**; check existing paper orders before trying again |

**A successful HTTP response is not proof of a fill.** Inspect the returned order status and use `kirke order get UUID` or `kirke orders --status all` to confirm what happened. The API may reject or partially fill an accepted order later. A missing/invalid response after POST is not evidence that no order was placed.

The HTTP layer never logs request headers, raw provider errors or full account data. It does not follow redirects and does not automatically retry non-idempotent POST requests. The original response is retained only in explicit private `--out` files (typically owner-only `0600`) after successful decoding and ID verification.

## Testing and agreed scope

Offline Hspec tests cover typed CLI inputs, valid market/limit/qty/notional cases, precision and symbol safety, mutually exclusive fields, JSON exactness, paper-only HTTP method/host/body/headers, sanitized error mapping, uncertain outcomes, and matching provider `client_order_id`. CI uses only synthetic credentials and provider fixtures, **never real POST requests**. Live paper integration is a manual, separate, explicitly opted-in exercise; neither `stack test` nor `scripts/cd.sh` submits orders.

Future items (not in this ticket): cancel/replace, equities/options, stop or stop-limit orders, advanced `order_class`, automatic idempotency/reconciliation, interactive confirmation dialogs, color or piping redesign, production/live trading, event-driven order status streaming, and project-wide ADR/triparity audits. CLI conventions stay deferred until the architecture review.

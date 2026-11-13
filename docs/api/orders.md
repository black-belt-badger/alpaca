# M3 — GET /v2/orders request-parameter fidelity (Kirke)

Scope: [Kirke M3 issue #35](https://github.com/black-belt-badger/kirke/issues/35) and paired [Medea #36](https://github.com/black-belt-badger/medea/issues/36). This page records **request phase 1** (merged in PR #51). Complete response parsing is covered separately in [response phase 2](orders-response.md); shared CLI conventions remain in issue #44.

Reference reviewed on 2026-11-13: [Alpaca GET /v2/orders](https://docs.alpaca.markets/us/reference/getallorders-1) and [published machine-readable OpenAPI](https://docs.alpaca.markets/us/reference/getallorders-1.md).

## Request contract

Read-only, authenticated `GET https://paper-api.alpaca.markets/v2/orders`. No path parameters or request body; response is a JSON array. Both query serialization and local pre-I/O validation must be explicit.

| Alpaca query parameter | Provider meaning | Kirke CLI | Implementation |
| --- | --- | --- | --- |
| `status` | `open`, `closed`, `all`; default `open` | `--status open|closed|all` | Typed; Kirke sends `open` explicitly by default |
| `limit` | Maximum response size, default 50, maximum 500 | `--limit 1..500` | Typed bounded integer; omitted by default (provider 50) |
| `after` | Exclusive lower bound on submission timestamp | `--after RFC3339` | Timezone-qualified timestamp; exact input precision preserved |
| `until` | Exclusive upper bound on submission timestamp | `--until RFC3339` | Timezone-qualified timestamp; exact input precision preserved |
| `direction` | `asc` or `desc`; default `desc` | `--direction asc|desc` | Typed; Kirke sends `desc` explicitly by default |
| `nested` | Roll multi-leg orders under the parent `legs` list | `--nested` | Boolean switch; `true` sent when supplied, omitted otherwise |
| `symbols` | Comma-separated trading symbols, crypto without slash | `--symbols BTCUSD,ETHUSD,AAPL` | Validated uppercase symbols; encoded CSV |
| `side` | Orders matching `buy` or `sell` | `--side buy|sell` | Closed typed enum |
| `asset_class` | Filter by one or more asset classes; special `all` | `--asset-class crypto,us_equity` | All ten published asset classes + `all`; strict CSV |
| `before_order_id` | Orders submitted before the server-issued order UUID (exclusive) | `--before-order-id UUID` | Canonical validated UUID |
| `after_order_id` | Orders submitted after the server-issued order UUID (exclusive) | `--after-order-id UUID` | Canonical validated UUID |

**Order class vocabulary:** `us_equity`, `us_option`, `crypto`, `crypto_perp`, `treasury`, `corporate`, `global_equity`, `us_index`, `us_equity_chain`, `ipo`, or `all`. The special `all` value must appear alone, not mixed with individual classes.

**Mutually exclusive pagination:** `--before-order-id` and `--after-order-id` cannot both be supplied, and neither may be used with `--after` or `--until`. Timestamp lower bounds cannot exceed the upper bound. Invalid combinations are rejected **before loading credentials** or performing HTTP. This API has **no page token** and the CLI does not automatically fetch multiple pages.

All supplied query values use the HTTP library's encoding and retain input precision; the client does not splice untrusted path or raw query string fragments.

## Examples

Read at most 50 open orders in descending submission-time order (existing defaults):

```sh
kirke orders
```

Retrieve ten crypto buy orders, grouping any legs under a parent order, and save original raw JSON privately:

```sh
kirke orders --status all --limit 10 --side buy \
  --asset-class crypto --nested --out output/orders.json
```

Filter orders within an exclusive submitted-at interval, with two asset classes:

```sh
kirke orders --status all --asset-class crypto,us_equity \
  --after 2026-11-01T00:00:00Z --until 2026-11-14T00:00:00Z
```

Navigate using a previously returned **server-issued** `id` (not `client_order_id`):

```sh
kirke orders --status all --limit 10 \
  --before-order-id 9275f66a-0a1b-4a22-8c55-167416c7cf14
```

The UUID in this example is illustrative, not an account-specific order. Use `--after-order-id` instead to navigate in the opposite cursor direction.

## Security, compatibility and checks

- Existing read-only paper host, authenticated HTTPS transport, status/direction defaults, limit validation, concise summaries, and private atomic `--out` JSON remain unchanged.
- Invalid tokens, malformed UUIDs, date-only values, unqualified timestamps, duplicate/empty/unknown class CSV values, and forbidden cursor/time combinations are rejected.
- Offline tests cover every documented query filter, serialization and encoding, all class enum members, timestamp precision, and cursor restrictions. Live opt-in `./scripts/cd.sh` exercises bounded side/class filtering; additional manual bounded live checks verified both UUID cursor directions and date intervals without printing credentials or private order data.
- Successful raw response bodies are exported unchanged, including unknown fields. This request-only PR does **not** expand the order response model.

## Deliberately deferred to response phase 2

Response phase 2 now decodes the published common and leg-specific order fields in a complete `Order`/`OrderDetails` model, with nullable values, exact decimal strings, typed open status/type/time-in-force/position-intent enums and nested legs. See the [response-field matrix](orders-response.md). Medea's implementation and the later triparity review remain separate.

Shared CLI diagnostics, color, Unix stream formatting and shell completion remain in [Kirke #44](https://github.com/black-belt-badger/kirke/issues/44) / [Medea #44](https://github.com/black-belt-badger/medea/issues/44). Do not introduce that design during request-fidelity work.
## Final endpoint acceptance: shared Kirke/Medea behavior

This final M3 endpoint pass keeps the existing observable CLI unchanged.
The language implementations are idiomatic but use the same six fabricated
orders from the shared fixture pack: partially-filled equity, notional crypto,
nested multi-leg options, bracket, trailing stop, and a future enum variant.

| Invocation or condition | Accepted behavior in both clients |
| --- | --- |
| `orders --help` | Lists documented query flags; no credentials or network |
| `orders` | Authenticated paper-only GET with explicit `status=open` and `direction=desc`, provider default limit 50 |
| `orders --status all --limit 10 --side buy --asset-class crypto,us_equity --nested` | All filters serialized, with `nested=true`; one page only |
| `orders --after RFC3339 --until RFC3339` | Exact timestamp spelling/offset preserved; incompatible or reversed bounds fail before credentials |
| `orders --before-order-id UUID` / `--after-order-id UUID` | Exclusive order-ID cursors; neither may be combined with the other cursor or time bounds |
| Invalid `--limit`, malformed symbols or unsupported/repeated filters | CLI error without network; no silently discarded filters |
| `[]` returned | Valid empty order list; `No matching orders.` on stdout, or untouched `[]` with `--out` |
| Nested/partial/crypto/option responses | Human summary includes exact decimal strings and typed legs; raw JSON includes all provider fields |
| `orders --out existing-dir/orders.json` | Decode *every* order first; atomically replace with original provider bytes and owner-only mode (0600 on Unix) |
| Malformed body, non-array, wrong-type financial field, invalid second order | Nonzero exit and fixed, sanitized invalid-response diagnostic; no partial stdout/export and existing destination unchanged |
| Missing credentials, HTTP 401/403/429/5xx or connection failure | Nonzero exit and sanitized message without provider response body or secrets |
| Unwritable output path | Nonzero exit; no success notice or leaked order data |

The acceptance tests deliberately exercise the **actual command presentation
and private-export boundary** rather than just the JSON decoder. They reuse
the identical `orders-mixed.json` fixture in both repositories and verify
byte-for-byte preservation, validation before output, lossless unknown-field
handling and private file replacement without live Alpaca credentials.

**Scope:** no new auto-pagination or output flags, no trades, and no new
order-write operations. Shared colors, redaction policy, shell completion
and Unix output conventions remain reserved for issue #44.

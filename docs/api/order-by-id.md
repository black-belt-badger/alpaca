# M3 — `GET /v2/orders/{order_id}` contract and behavior

**Tracking:** [Kirke #36](https://github.com/black-belt-badger/kirke/issues/36). The original CLI was implemented in M2; this work completes M3 request, response, and failure-path coverage without introducing order creation, cancellation, replacement, or live trading.

**Alpaca source:** [Get Order by ID](https://docs.alpaca.markets/us/reference/getorderbyorderid-1). This endpoint is not the distinct `GET /v2/orders:by_client_order_id` operation.

## Request coverage matrix

| Provider field / behavior | Kirke request | Tests and decision |
| --- | --- | --- |
| `GET https://paper-api.alpaca.markets/v2/orders/{order_id}` | `kirke order get UUID` | Fixed paper HTTPS host and GET method, credentials in protected headers, no redirects, timeout |
| Required `order_id` UUID | `parseOrderId` abstract `OrderId`, then `orderIdSegment` | Rejects missing, malformed, path/query/fragment injection and non-ASCII hex before authenticated I/O |
| Optional `nested` boolean | Omitted by default; `--nested` sends `nested=true` | The documented false/default is represented by absence, not an extra `--nested=false` switch. Explicit false is an optional future CLI ergonomics discussion |
| Response | Single JSON object | Uses the same `decodeOrder` as listing; arrays, scalars, invalid required fields and malformed legs fail |
| Response order identity | UUID matching requested UUID | Compares text case-insensitively to account for uppercase hex; mismatched primary ID becomes an error without revealing either identifier |
| Output | Human-readable summary or `--out PATH` | Nested leg count, symbol, side, precise `ratio_qty` shown when present; raw JSON bytes retained intact with private atomic save |

## Response fields

All documented fields, class-dependent nullable values and open typed enums are covered in the [shared order-response matrix](orders-response.md) from [Kirke #35](https://github.com/black-belt-badger/kirke/issues/35).

The same decoder supports partial fills, notional crypto orders (null `qty`), bracket/OTO/OCO orders, multi-leg options with a null parent `side`, trailing stops, replacement IDs, optional timestamps, and exact decimal strings including `ratio_qty`. The `legs` value may be null, absent, empty, or a list of typed child orders, but nonempty grandchildren are rejected. Unknown new status/class/side strings remain readable via the open Haskell ADTs.

Full wire-fidelity is guaranteed for `--out` because we write **the original successful HTTP body**, not the result of reserializing parsed records. Unknown extension objects and long numeric literals therefore survive even when the typed summary omits them.

## Error behavior

| Provider/result | Kirke behavior |
| --- | --- |
| 200 with valid matching order | Print summary, or save original JSON to the requested private file |
| 404 | Distinct `Alpaca paper order not found (HTTP 404).` diagnostic and nonzero CLI exit |
| 401 | Credentials rejected diagnostic, distinct from absence |
| 403, 429, 5xx | Typed HTTP status converted into sanitized diagnostic and nonzero exit |
| Transport/timeout failure | Generic network diagnostic; no request/secret leakage |
| 200 with malformed JSON or unexpected data types | Sanitized `Invalid Alpaca order response` error |
| 200 with different `id` | Sanitized order-ID mismatch error; never display or save an unrelated order |

**Atalanta difference:** the Java library treats an order-ID 404 as `Result.Ok(Optional.empty())); Kirke is a CLI and reports a nonzero not-found diagnostic. This observable/API distinction is recorded for the planned [triparity audit](https://github.com/black-belt-badger/atalanta/issues/26), not silently reconciled here.

## Offline regression coverage

- End-to-end HTTP request construction from validated UUIDs, omission of default `nested` and exact `nested=true`, paper-only TLS, auth headers and redirect protection.
- Request parsing/help, invalid UUID/flags, single-order vs list-order distinction.
- Synthetic Atalanta `alpaca-trading-read-only/1.0.0` fixtures for an equity partial fill, crypto notional order and nested multi-leg option ratios; unchanged response bytes.
- Explicit case-insensitive UUID matching, successful response with mismatched ID, invalid JSON shapes and missing fields.
- Distinct 404, 401, 403, 429, 503 and transport errors with no sensitive provider body.
- Reuse of the shared order decoder and existing private-output writer tests. No live credentials or external HTTP calls in CI.

## Explicitly deferred product decisions

The existing concise summary remains the default; `--nested` and `--out` retain their current meanings. A richer detailed view, explicit `--nested=false`, unified stdout/stderr/ANSI/exit-status conventions, machine-readable piping and bash completion should be agreed at [Kirke #44](https://github.com/black-belt-badger/kirke/issues/44), with the paired Medea discussion. This endpoint issue does **not** grant permission for a CLI-wide redesign.

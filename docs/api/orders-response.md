# M3 — GET /v2/orders response fidelity (Kirke)

Scope: [Kirke #35](https://github.com/black-belt-badger/kirke/issues/35), phase 2, following [request-filter phase 1 / PR #51](https://github.com/black-belt-badger/kirke/pull/51). This same `Alpaca.Domain.Order` decoder is used by both `kirke orders` and `kirke order get UUID`; dedicated order-by-ID ergonomics remain in [#36](https://github.com/black-belt-badger/kirke/issues/36).

Reference: [Alpaca Get All Orders](https://docs.alpaca.markets/us/reference/getallorders-1) and [Get Order by ID](https://docs.alpaca.markets/us/reference/getorderbyorderid-1), including the embedded `legs` schema.

## Decoder shape

```haskell
decodeOrders :: ByteString -> Either String [Order]
decodeOrder  :: ByteString -> Either String Order
```

A collection response must be an array (`[]` is valid); a single-order response must be an object. We validate documented wire types and the required **nonblank `id`** and **`status`**. Fields that Alpaca can omit or set to JSON null (notably the parent `side` on an `mleg` options order) become `Maybe`. This makes the model tolerant of both complete responses and class-dependent/child-leg shapes without inventing defaults.

The `Order` record contains the frequently used summary fields, a separate `OrderDetails` record for additional published fields, and `Maybe [Order]` for typed nested legs. Legs are allowed **one level deep**, with missing/null distinguished from an explicit empty array where relevant. Nonempty grandchildren, scalar legs and malformed members fail decoding.

## Response coverage matrix

| Provider fields | Kirke model | Interpretation |
| --- | --- | --- |
| `id`, `status` | `orderId :: Text`, `orderState :: OrderState` | Required; ID checked nonblank; UUID syntax checked on **request** CLI |
| `client_order_id`, `symbol`, `asset_class` | `Maybe Text` | Optional/class-dependent; no fabricated placeholders inside the model |
| `side`, `type` | `Maybe OrderSide`, `Maybe OrderType` | Typed known and unknown provider enum members; null parent `side` permitted for multi-leg options |
| `qty`, `notional`, `filled_qty`, `filled_avg_price` | `Maybe Text` | Exact decimal strings; notional and quantity may be mutually exclusive/null |
| `limit_price`, `stop_price` | `Maybe Text` | Exact decimal strings; absent/null not converted into zero |
| `created_at`, `submitted_at`, `filled_at` | `Maybe Text` | Original provider timestamp spelling/precision retained |
| `asset_id`, `replaced_by`, `replaces`, `group_id` | `Maybe Text` in `OrderDetails` | Opaque provider identifiers |
| `position_intent`, `order_class`, `time_in_force` | `Maybe OrderPositionIntent`, `Maybe OrderClass`, `Maybe OrderTimeInForce` | Open, typed enums with forward-compatible unknown constructors |
| `order_type` | `Maybe Text` | Deprecated field supported without equating it to `type` |
| `trail_price`, `trail_percent`, `hwm`, `ratio_qty` | `Maybe Text` in `OrderDetails` | Precise optional trailing/option-leg parameters; `ratio_qty` never converted to `Double` |
| `extended_hours` | `Maybe Bool` | Strict JSON boolean, not string or number |
| `updated_at`, `expired_at`, `canceled_at`, `failed_at`, `replaced_at`, `expires_at` | `Maybe Text` | Optional event/expiry timestamps |
| `group_role`, `source`, `subtag` | `Maybe Text` | Provider grouping and opaque metadata |
| `legs` | `Maybe [Order]` | Nullable or empty; typed bracket/OTO/OCO/multi-leg children, nonempty grandchildren rejected |
| Unknown future fields | Original response body | **Raw `--out` saves original bytes**, including unknown fields and precise numeric JSON literals |

Financial amounts and quantities remain **exact decimal strings**; a malformed numeric JSON value for a documented decimal-string field is rejected instead of being converted through floating point. Unknown enum strings remain intact through `*Other Text` constructors, rather than failing an entire otherwise-valid response. The provider also represents simple `order_class` as either `"simple"` or `""`; Kirke recognizes both as `ClassSimple`.

There are six open enum types: `OrderSide`, `OrderState`, `OrderType`, `OrderClass`, `OrderTimeInForce`, `OrderPositionIntent`. Their `FromJSON`/`ToJSON` instances preserve future string values; a blank status, side or type is rejected. This is an intentional idiomatic Haskell representation, **not** a requirement that the Java or Rust client use the same constructors.

## CLI and security behavior

- Existing **paper-only** authenticated GET transport, request defaults and manual pagination are unchanged.
- Human-readable output retains the existing concise order summary and now includes a leg count and each leg's symbol, side, exact `ratio_qty` and state when nested children exist.
- `--out PATH` continues to save the complete raw provider JSON atomically with private permissions. The typed response does **not** attempt a lossy reserialization of unknown provider fields.
- `kirke order get UUID` uses this same decoder; 404 remains a distinct CLI error message, not silently transformed into an empty order. Compare to Atalanta's `Ok(Optional.empty())` during triparity.
- Diagnostics, machine-readable stdout, ANSI color, exit-status standardization, and completion are **deliberately deferred** to [Kirke #44](https://github.com/black-belt-badger/kirke/issues/44) / [Medea #44](https://github.com/black-belt-badger/medea/issues/44). No CLI-wide contract or new flags are implicitly chosen here.

## Offline acceptance

The tests include snapshots of seven **synthetic** Atalanta `alpaca-trading-read-only/1.0.0` order fixtures: partially-filled US equity, precise crypto notional order, multi-leg options with `ratio_qty`, bracket stop leg, trailing stop, future enum values, and six-item mixed collection. These test parsing and rendered leg summaries without any real account data or network calls.

Additional Hspec cases cover empty arrays, invalid JSON shapes, null versus empty legs, malformed nested grandchildren, invalid financial/bool types, empty order identifiers/statuses, and known/future enum round-trips. The included fixture snapshots are **not yet a shared automatic cross-language runner**; that comparison belongs to the later [triparity audit](https://github.com/black-belt-badger/atalanta/issues/26).

**Known boundary:** Kirke's Haskell domain decoder keeps known fields typed and exports unknown fields only in the original `--out` body; Atalanta additionally exposes extension maps in its Java records. Evaluate whether that is an acceptable intentional public-API difference during the review rather than changing this working CLI without a decision.

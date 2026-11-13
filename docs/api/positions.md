# M3 — GET /v2/positions API fidelity (Kirke)

Scope: [Kirke #34](https://github.com/black-belt-badger/kirke/issues/34), paired with [Medea #35](https://github.com/black-belt-badger/medea/issues/35).

Verified against Alpaca's [All Open Positions reference](https://docs.alpaca.markets/us/reference/getallopenpositions) and [machine-readable OpenAPI](https://docs.alpaca.markets/us/reference/getallopenpositions.md) on 2026-11-13.

## Request contract

| Property | Behavior |
| --- | --- |
| HTTP operation | Authenticated `GET https://paper-api.alpaca.markets/v2/positions` |
| Path parameters | None (unlike the **separate** `GET /v2/positions/{symbol_or_asset_id}` endpoint) |
| Query parameters | **None**; all currently open positions, across asset classes, are returned |
| Request body | None |
| CLI | `kirke positions` or `kirke positions --out PATH`; only output location changes |
| Empty account | `[]` (valid response, shows `No open positions.`) |
| History | Not a history endpoint: closed positions are not returned |

This endpoint is **read-only** and bound to paper credentials; it neither closes a position nor places a trade. Reject other paths, unexpected response shapes and invalid JSON types. HTTP/network errors are sanitized without including credentials or sensitive provider bodies.

## Response: all 22 documented fields

Alpaca's current OpenAPI marks **17** fields required. Five fields are optional, including the local-currency `usd` object. `Position` has typed fields for every property, preserving decimal spellings as **Text**, never `Double` or floating-point numbers.

| JSON property | Haskell representation | Schema |
| --- | --- | --- |
| `asset_class` | `AssetKind` | Required |
| `asset_id` | `Text (UUID wire string)` | Required |
| `asset_marginable` | `Bool` | Required |
| `avg_entry_price` | `Text (exact decimal)` | Required |
| `avg_entry_swap_rate` | `Maybe Text (exact decimal)` | Optional |
| `change_today` | `Text (decimal fraction)` | Required |
| `cost_basis` | `Text (exact decimal)` | Required |
| `current_price` | `Text (exact decimal)` | Required |
| `exchange` | `AssetVenue` | Required |
| `lastday_price` | `Text (exact decimal)` | Required |
| `market_value` | `Text (exact decimal)` | Required |
| `prev_swap_rate` | `Maybe Text (exact decimal)` | Optional |
| `qty` | `Text (exact decimal)` | Required |
| `qty_available` | `Maybe Text (exact decimal)` | Optional |
| `side` | `PositionSide` | Required |
| `swap_rate` | `Maybe Text (exact decimal)` | Optional |
| `symbol` | `Text` | Required |
| `unrealized_intraday_pl` | `Text (exact decimal)` | Required |
| `unrealized_intraday_plpc` | `Text (decimal fraction)` | Required |
| `unrealized_pl` | `Text (exact decimal)` | Required |
| `unrealized_plpc` | `Text (decimal fraction)` | Required |
| `usd` | `Maybe UsdPositionValues` | Optional (LCT accounts) |

### Optional USD-denominated values

The nested `usd` property is returned for **LCT (local currency trading)** accounts only. The `UsdPositionValues` object defines ten fields, but only `avg_entry_price` and `cost_basis` are required *when the object is present*.

| USD sub-property | Haskell representation | Schema |
| --- | --- | --- |
| `avg_entry_price` | `Text` | Required |
| `change_today` | `Maybe Text` | Optional |
| `cost_basis` | `Text` | Required |
| `current_price` | `Maybe Text` | Optional |
| `lastday_price` | `Maybe Text` | Optional |
| `market_value` | `Maybe Text` | Optional |
| `unrealized_intraday_pl` | `Maybe Text` | Optional |
| `unrealized_intraday_plpc` | `Maybe Text` | Optional |
| `unrealized_pl` | `Maybe Text` | Optional |
| `unrealized_plpc` | `Maybe Text` | Optional |

Native-currency and USD-denominated values are not interchangeable and are not summed automatically.

### Enumerations and compatibility

- `asset_class`: reuse `AssetKind` from the assets endpoint, with all ten documented class members and a forward-compatible `KindOther Text`.
- `exchange`: reuse `AssetVenue` with all known venue values and `VenueOther Text`. The positions endpoint additionally allows **the empty string** for a position without an applicable exchange; it is represented explicitly by `VenueNone`.
- `side`: new `PositionSide` with `SideLong`, `SideShort`, and `SideOther Text` for unforeseen future strings.
- Required booleans are actual JSON booleans (not strings or numbers). Decimal fields are *JSON strings*, with full original precision.
- Percent-change fields use Alpaca's **fraction convention** (e.g. a decimal of `0.01` means one percent); we preserve rather than reinterpret their supplied representation.
- Unknown provider fields are ignored by typed decoding but kept in the **original response bytes**, written unchanged with `--out PATH`.

For optional fields, absent and explicit JSON null both become `Nothing`, while `"0"`, `"-0.001"` and other present numeric strings remain `Just Text`. Raw `--out` retains the distinction between absent and null. A missing/null *required* field is a decoding error, consistent with current OpenAPI.

## User-visible output

The concise summary remains backward-compatible for valid position arrays:

- One line per position: `SYMBOL (asset_class, side)`.
- Exact quantity, market value, current price, and unrealized P/L.
- `No open positions.` for the empty portfolio; no aggregation or inferred FX conversion.
- `--out PATH` saves the complete **unmodified** position JSON array privately and atomically, with owner-only permissions. No new flags or altered stdout formats in this phase.

## Offline and integration coverage

- All 22 fields, all ten nested USD fields, long fractional quantities, signed/zero decimal strings and full precision.
- Required/optional/null distinction, missing required fields, wrong JSON types (including numeric-vs-string price values), and nested USD's two required properties.
- Crypto/equity/option class and side variants, documented empty exchange, future enum strings and unknown provider properties.
- Empty positions array; non-array/malformed responses; no query parameters; authenticated paper endpoint.
- Opt-in `./scripts/cd.sh` validates actual paper positions and private JSON output without putting account details or credentials in CI.

**Intentionally deferred:** external CLI ergonomics, portfolio aggregation, FX normalization, additional date/UUID format validation, color/diagnostics and Unix pipeline behavior. Those common enhancements belong to [Kirke #44](https://github.com/black-belt-badger/kirke/issues/44) and [Medea #44](https://github.com/black-belt-badger/medea/issues/44), after the M3 API audit. Parent positions issue #34 stays open pending final review and Rust parity.

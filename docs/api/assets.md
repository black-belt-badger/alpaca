# M3 — GET /v2/assets API fidelity

Scope: [Kirke #33](https://github.com/black-belt-badger/kirke/issues/33), paired with [Medea #34](https://github.com/black-belt-badger/medea/issues/34).

Source verified 2026-11-13: [Alpaca GET /v2/assets](https://docs.alpaca.markets/us/reference/get-v2-assets-1) and its [machine-readable OpenAPI description](https://docs.alpaca.markets/us/reference/get-v2-assets-1.md). This is API fidelity work, not the deferred common terminal/diagnostics contract.

## Request coverage

| Provider parameter | Provider semantics | Kirke CLI |
| --- | --- | --- |
| `status` | Optional; omitted = all statuses, `active`/`inactive`; explicit `all` remains supported for compatibility | `--status active\|inactive\|all` |
| `asset_class` | Optional; Alpaca default **us_equity** | `--asset-class CLASS`; Kirke deliberately defaults **crypto**, sent explicitly |
| `exchange` | Comma-separated **equity or index** exchanges; INDEX requires asset class us_index; no crypto filtering | `--exchange NASDAQ,NYSE` or `--asset-class us_index --exchange INDEX` |
| `attributes` | Comma-separated values, **OR** semantics: include assets having any selected attribute | `--attributes has_options,ipo` |
| Request method/host | `GET https://paper-api.alpaca.markets/v2/assets` | Fixed read-only paper endpoint over HTTPS, authenticated headers |

### Asset classes (10)

`us_equity`, `us_option`, `crypto`, `crypto_perp`, `treasury`, `corporate`, `global_equity`, `us_index`, `us_equity_chain`, `ipo`.

**Do not confuse** `--asset-class ipo` with the separate `--attributes ipo` filter.

### Exchange query filter (9)

`AMEX`, `ARCA`, `BATS`, `NYSE`, `NASDAQ`, `NYSEARCA`, `OTC`, `TXSE`, `INDEX`.

- For `us_equity`, reject `INDEX`.
- For `us_index`, accept only `INDEX`.
- Reject `--exchange` for `crypto`, `crypto_perp`, options, and other non-equity/index classes, rather than silently sending an ineffective filter.
- Additional crypto/crypto-perpetual venue values such as `CRYPTO`, `ERSX`, `CRXL`, `ASCX` are **valid response exchange enums** but not accepted exchange filters for this endpoint.
- Filter validation precedes credential loading and any network I/O.

### Attribute query filter (8)

`ptp_no_exception`, `ptp_with_exception`, `ipo`, `has_options`, `options_late_close`, `fractional_eh_enabled`, `overnight_tradable`, `overnight_halted`.

CSV input accepts spaces after separators; empty, unknown or duplicated values are rejected. Query strings are encoded by the HTTP client, not interpolated into URLs. Neither missing filter is sent implicitly.

**Example:**

```sh
kirke assets --asset-class us_equity --status active \
  --exchange NASDAQ,NYSE --attributes has_options,overnight_tradable \
  --out output/assets.json
```

This asks for US equities on either exchange with **either** attribute; an empty array is a valid result.

## Response coverage: 19 documented fields

The schema declares ten required properties, enforced by the decoder. The other nine may be absent or null and are represented as `Maybe`.

| Alpaca property | Haskell type | Requirement |
| --- | --- | --- |
| `id` | `Text` | Required |
| `class` | `AssetKind (open enum)` | Required |
| `exchange` | `AssetVenue (open enum)` | Required |
| `symbol` | `Text` | Required |
| `name` | `Text` | Required |
| `status` | `AssetState (open enum)` | Required |
| `tradable` | `Bool` | Required |
| `marginable` | `Bool` | Required |
| `shortable` | `Bool` | Required |
| `fractionable` | `Bool` | Required |
| `attributes` | `Maybe [AssetAttributeValue]` | Optional |
| `borrow_status` | `Maybe BorrowStatus` | Optional |
| `cusip` | `Maybe Text (nullable)` | Optional |
| `maintenance_margin_requirement` | `Maybe Scientific (deprecated JSON number)` | Optional |
| `margin_requirement_long` | `Maybe Text (decimal string)` | Optional |
| `margin_requirement_short` | `Maybe Text (decimal string)` | Optional |
| `min_order_size` | `Maybe Text (decimal string)` | Optional |
| `min_trade_increment` | `Maybe Text (decimal string)` | Optional |
| `price_increment` | `Maybe Text (decimal string)` | Optional |

### Enum handling and exact values

- Asset class: all **10** documented values explicitly modeled, plus `KindOther Text`.
- Exchange: all **13** documented provider values (including crypto venues) explicitly modeled, plus `VenueOther Text`.
- Status: `active`, `inactive`, plus `StateOther Text`.
- Attributes: all eight documented attributes plus `AttributeOther Text`.
- Borrow status: `easy_to_borrow`, `hard_to_borrow`, plus `BorrowOther Text`.
- Known boolean fields are strictly boolean; conditional margin/size/price fields encoded as decimal **strings** remain exact `Text` without conversion. The deprecated `maintenance_margin_requirement` is a JSON **number**, decoded as `Scientific` without floating-point rounding.
- Extra/undocumented fields are ignored for typed decoding but retained **byte-for-byte** in the `--out` response. The live crypto response currently contains `easy_to_borrow`, which is not a documented property of this schema. It is deliberately not made required or conflated with `borrow_status`.
- Unknown enum strings do not crash an otherwise valid response; invalid JSON types do. A single JSON object instead of the required array is rejected.

## Behavioral compatibility

`kirke assets` still defaults to **crypto** despite Alpaca's **us_equity** API default, as in v0.2.0.0. Existing `--asset-class`, `--status`, `--out` and readable summary formats remain unchanged. Output files are original JSON written atomically with owner-only permissions. No live account access, write endpoints, shell color, diagnostics engine, JSON stdout flag or Unix pipe redesign is added here.

## Tests and parity

Offline: all documented request values; CSV boundaries and combinations; query encoding; unsupported exchange/class combinations; known/future response enum values; required/optional response fields; long decimal strings; malformed types, zero/empty results and sanitization. No credentials in public CI.

Opt-in paper API integration validates existing crypto behavior plus an equity/exchange/attribute request and private file mode.

**Medea parity:** Rust should use the same CLI flags, defaults, request restrictions, response fidelity and raw JSON behavior, allowing idiomatic Rust types. Broader CLI ergonomics remain [Kirke #44](https://github.com/black-belt-badger/kirke/issues/44) and [Medea #44](https://github.com/black-belt-badger/medea/issues/44). Parent asset M3 issues stay open for final acceptance review.

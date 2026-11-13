# Historical crypto quotes — Kirke CLI

**Endpoint:** authenticated, read-only `GET https://data.alpaca.markets/v1beta3/crypto/{loc}/quotes`. This is public-market-data retrieval with API authentication, **not** account activity, order execution or live trading.

## Usage

```sh
# Concise one-page summary grouped by symbol
kirke crypto quotes --symbols BTC/USD,ETH/USD --location us \
  --start 2026-10-02T00:00:00Z --end 2026-10-03T00:00:00Z

# Bounded multi-page complete provider page envelopes
kirke crypto quotes --symbols BTC/USD,SOL/USD --limit 500 \
  --max-pages 3 --sort asc --out output/quotes.json

# One symbolized bid/ask observation per line
kirke crypto quotes --symbols BTC/USD --format jsonl \
  --max-pages 2 --out output/btc-quotes.jsonl

# Explicit resumption with a server-provided opaque token
kirke crypto quotes --symbols BTC/USD --page-token 'TOKEN_FROM_PREVIOUS_JSON' \
  --max-pages 2 --out output/quotes-next.json
```

Use `stack exec -- kirke` instead of `kirke` to run an uninstalled checkout.

## Request contract

| Provider field | CLI flag | Behavior |
| --- | --- | --- |
| `loc` | `--location` | Typed `us` (default), `us-1`, `us-2`, `eu-1`, `bs-1`; safe allowlisted path segment |
| `symbols` | `--symbols` | Required: 1–30 comma-separated `BASE/QUOTE` pairs, e.g. `BTC/USD,ETH/USD` |
| `start` | `--start` | Optional inclusive calendar date or timezone-qualified RFC3339 timestamp |
| `end` | `--end` | Optional inclusive date/timestamp; invalid or reversed bounds rejected before authentication |
| `limit` | `--limit` | 1–10,000, default 1,000 **per response page in total across symbols**, not per symbol |
| `sort` | `--sort` | `asc` (default) or `desc` |
| `page_token` | `--page-token` | Opaque provider token, percent-encoded by the HTTP library |
| Local bound | `--max-pages` | 1–20, default **1**; stop at page limit or the end token |
| Serialization | `--format json\|jsonl`, `--out PATH` | Default format `json`: human summary when no path, complete API page envelopes when writing a file; `jsonl` streams records |

**There is no `--timeframe`:** quotes are timestamped bid/ask observations, not aggregated OHLCV bars. Empty results and short pages are valid. A short page does not imply completion: only a null/empty provider continuation token or the local page limit ends retrieval. The CLI keeps the final token so further pages can be requested manually.

## Response model and precision

A provider page has a `quotes` object mapping each symbol to a list of observations, and an optional `next_page_token`.

| JSON member | Haskell type | Meaning |
| --- | --- | --- |
| `quotes` | `Map Text [CryptoQuote]` | Quotes indexed by symbol; empty object and empty per-symbol arrays valid |
| `ap` | `Scientific` | Ask price |
| `as` | `Scientific` | Ask size, measured in the base asset |
| `bp` | `Scientific` | Bid price |
| `bs` | `Scientific` | Bid size, measured in the base asset |
| `t` | `Text` | Original RFC3339 exchange timestamp text, including nanosecond digits |
| `next_page_token` | `Maybe Text` | Optional opaque continuation; null/missing/empty treated as end |
| Unknown properties | `CryptoQuotesPage.pageOriginal :: Value` | Future provider metadata retained in each JSON page envelope |

A sample page:

```json
{
  "quotes": {
    "BTC/USD": [
      {
        "ap": 29059,
        "as": 3.252,
        "bp": 29058,
        "bs": 0.3544,
        "t": "2022-05-26T11:47:18.44347136Z"
      }
    ]
  },
  "next_page_token": null
}
```

`Scientific` stores exact decimal numeric values; no prices or sizes pass through a binary floating-point `Double`. JSON encoding may normalize whitespace, key order or **decimal notation**, but it does not round the number. Timestamp strings keep their provider text. Invalid/missing numeric fields, wrong scalar types, invalid root shapes and malformed JSON are rejected rather than silently guessed.

The default `--out PATH --format json` writes:

```json
{"pages":[{"quotes":{"BTC/USD":[]},"next_page_token":null}],"next_page_token":null}
```

Each `pages` entry is the complete decoded provider envelope, including undocumented fields; the trailing token comes from the last fetched page. `--format jsonl` emits one object with `symbol`, `ap`, `as`, `bp`, `bs` and `t` per quote. JSONL does **not** include unknown quote fields or the continuation token; choose JSON to preserve those.

## Bounded streaming and security

- Same authenticated HTTPS-only, no-redirect market-data transport as Bars and Trades; 20-second request timeout.
- Handles **one provider page at a time**, accumulating only counts and the latest token, not an unbounded array of the full history.
- Rejects repeated page tokens; maximum 20 pages per invocation.
- Private `--out` files are written with a temporary file and only renamed on full success (normally owner-only mode `0600`). A later HTTP, decoding or writer failure rolls back partial output without replacing an existing destination; the destination's parent directory must already exist.
- JSONL streamed to **stdout** cannot be rolled back once printed; use `--out` for all-or-nothing output.
- Invalid parameters, credentials, transport failures, HTTP errors, and bad provider JSON produce sanitized diagnostics. API keys and provider error bodies do not enter logs or public CI.

Offline tests cover exact long decimals, multiple symbols, future provider properties, malformed types, token cycling, bounded paging, query encoding, private file rollback, JSON/JSONL output and CLI parsing. The opt-in `./scripts/cd.sh` uses a **small, bounded** authenticated live sample; CI uses synthetic data only.

This is a bounded data-access tool, not Metis/Ariadne historical coverage planning or a bulk backfill engine. Broader output, colors, Unix piping and completion design are intentionally deferred until the triparity review.

## References

- [Alpaca historical crypto quotes](https://docs.alpaca.markets/us/reference/cryptoquotes-1)
- [Medea historical quotes implementation](https://github.com/black-belt-badger/medea/pull/54)
- [Kirke issue #19](https://github.com/black-belt-badger/kirke/issues/19)

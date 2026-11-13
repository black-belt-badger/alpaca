<p align="center">
  <img src="docs/fancy.webp" alt="Kirke — Celtic-knot logo and wordmark" width="760">
</p>

# Kirke — Haskell CLI for Alpaca's Trading and Crypto Market Data APIs

[![Haskell CI](https://github.com/black-belt-badger/kirke/actions/workflows/haskell-ci.yml/badge.svg)](https://github.com/black-belt-badger/kirke/actions/workflows/haskell-ci.yml)
[![License: BSD-3-Clause](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](LICENSE)

**Kirke** is an open-source, unofficial Haskell command-line application for accessing [Alpaca's APIs](https://docs.alpaca.markets/). It offers **read-only account information, open positions, asset discovery, and order history** from Alpaca paper trading, plus **historical crypto bars, trades and quotes** from the market-data API. An explicitly confirmed **paper-only crypto order submission** command is also available; it defaults to a credential-free dry run. It is not affiliated with, sponsored by, or endorsed by Alpaca Markets.

The GitHub repository, Haskell package, and command-line executable are named **Kirke** (`kirke`). Its provider-specific Haskell modules intentionally remain under `Alpaca.*`.

The project is early in development. Its first goal is a small, useful, testable CLI; additional commands may follow as separate issues.

## Current functionality

| Command | Behavior |
| --- | --- |
| `kirke --help` | List commands and general options |
| `kirke account --help` | Show account-specific options |
| `kirke account` | Fetch a paper account and print a readable summary |
| `kirke account --out PATH` | Fetch a paper account and save the complete API JSON response |
| `kirke positions --help` | Show open-position options |
| `kirke positions` | List current open positions (crypto and equities) |
| `kirke positions --out PATH` | Save the complete unmodified JSON array of positions |
| `kirke assets` | List available crypto assets (explicit default) |
| `kirke assets --asset-class us_equity` | List available US equities |
| `kirke assets --status active --out PATH` | Filter assets and save original JSON privately |
| `kirke assets --asset-class us_equity --exchange NASDAQ,NYSE` | Filter US equities by one or more exchanges |
| `kirke assets --asset-class us_equity --attributes has_options,ipo` | Match assets having either requested attribute |
| `kirke assets --asset-class us_index --exchange INDEX` | Filter index symbols using the INDEX exchange |
| `kirke orders` | List open paper orders, most recent first |
| `kirke orders --status all --limit 10` | Inspect up to 10 recent orders |
| `kirke orders --symbols BTCUSD,ETHUSD --direction asc` | Filter orders by symbol and submission order |
| `kirke orders --out PATH` | Save complete, unmodified order JSON privately |
| `kirke order get ORDER_ID` | Fetch an individual paper order using its server UUID |
| `kirke order get ORDER_ID --nested --out PATH` | Include nested order legs when supported; save complete private JSON |
| `kirke crypto bars --symbols BTC/USD --timeframe 1Hour` | Retrieve one bounded page of historical crypto OHLCV bars |
| `kirke crypto bars --symbols BTC/USD,ETH/USD --timeframe 5Min --max-pages 2 --out PATH` | Follow up to two pages and save the JSON page envelopes privately |
| `kirke crypto bars --symbols BTC/USD --timeframe 1Min --format jsonl --out PATH` | Save one JSONL record per bar |
| `kirke crypto trades --symbols BTC/USD,ETH/USD` | Fetch a bounded page of individual historical executions |
| `kirke crypto trades --symbols BTC/USD --max-pages 2 --out PATH` | Save complete trade pages and continuation token privately |
| `kirke crypto trades --symbols BTC/USD --format jsonl --out PATH` | Stream symbolized trade records to an atomic private JSONL file |
| `kirke crypto quotes --symbols BTC/USD,ETH/USD` | Fetch bounded historical crypto bid/ask quotes |
| `kirke crypto quotes --symbols BTC/USD --max-pages 2 --out PATH` | Export complete quote pages and continuation token |
| `kirke crypto quotes --symbols BTC/USD --format jsonl --out PATH` | Stream exact-decimal symbolized quotes privately |

The summary includes account number, status, currency, cash, equity, buying power, trading-blocked flag, and crypto status. Both statuses are typed account-status enums (not boolean ACTIVE/INACTIVE flags); they retain new Alpaca values safely. The account response decoder now covers all currently documented fields, including typed options-level enums and nullable/optional values. When a summary field is unavailable it displays `not provided`. See the [M3 account coverage notes](docs/api/account.md).

**Not implemented:** live-account access, order submission/cancellation, live streaming, and shell completion. Listing positions does **not** close them or place orders. No trading decisions are made or orders placed.

## Requirements

- Linux or another compatible Unix-like system (Unix permissions are part of the output-file behavior and test suite).
- [GHC](https://www.haskell.org/ghc/) **9.10.3** installed.
- [Stack](https://docs.haskellstack.org/) **3.11.1** (the version used for development and CI).
- An [Alpaca paper trading account](https://alpaca.markets/) with **paper API credentials** for authenticated commands.

The repository pins a Stackage snapshot in `stack.yaml` and tracks `stack.yaml.lock`. Its configuration expects a locally installed GHC; Stack does not automatically install one.

## Build and test

```sh
git clone https://github.com/black-belt-badger/kirke.git
cd kirke
stack build
stack test
stack exec -- kirke --help
```

Offline tests do **not** require an Alpaca account or credentials. The same build and test commands run in [GitHub Actions CI](https://github.com/black-belt-badger/kirke/actions).

For local installation instead of `stack exec`, run `stack install` and make sure Stack's executable installation directory is on your `PATH`.

## Configure paper credentials

Alpaca authenticates the paper account request using two environment variables:

- `APCA_API_KEY_ID`
- `APCA_API_SECRET_KEY`

The application sends them as HTTP headers over HTTPS to the paper API at **`https://paper-api.alpaca.markets`**. It does not use the live trading endpoint.

For interactive use, you can source a private credentials file **outside this repository**. On Linux:

```sh
install -d -m 700 "$HOME/.config/kirke"
umask 077
${EDITOR:-vi} "$HOME/.config/kirke/credentials"
chmod 600 "$HOME/.config/kirke/credentials"
```

Put the following lines in that file, replacing only the obvious placeholders with your **paper** credentials:

```sh
export APCA_API_KEY_ID="YOUR_PAPER_KEY_ID"
export APCA_API_SECRET_KEY="YOUR_PAPER_SECRET_KEY"
```

Load them into your shell before calling the CLI:

```sh
source "$HOME/.config/kirke/credentials"
```

Only source a credentials file you created and trust. Don't paste real credentials into issues, PRs, screenshots, shell commands saved in history, CI logs, or the repository. You can also provide these environment variables by other secure means; no specific file location is required by the application.

For a nondefault config location, the developer-only integration script respects `XDG_CONFIG_HOME`.

## Usage

Print your paper account summary:

```sh
stack exec -- kirke account
```

Illustrative output (account details deliberately omitted):

```text
Kirke — Alpaca paper account
Account number: [redacted]
Status: ACTIVE
Currency: USD
Cash: [redacted]
Equity: [redacted]
Buying power: [redacted]
Trading blocked: no
Crypto status: ACTIVE
```

**The actual summary contains your account number and balances. Treat its terminal output as sensitive.**

Save the original, **complete** response as JSON:

```sh
mkdir -p output
chmod 700 output
stack exec -- kirke account --out output/account.json
```

On Unix, the CLI writes through a private temporary file and atomically replaces the destination, resulting in owner-only file permissions (typically `0600`). The parent directory must already exist. Use a private directory; the full API response can contain additional sensitive account data.

Files in `output/` are ignored by Git. Do not publish them.

## Positions: crypto and equities

List **all current open positions** (the endpoint has no symbol filter):

```sh
stack exec -- kirke positions
```

The response includes crypto and equity positions together. Each row shows the symbol, typed asset class and long/short side, exact quantity, market value, current price, and unrealized P/L. The decoder covers all **22 documented position properties**, including exact decimal strings, required flags, available quantity, swap rates, and the optional nested USD value object for local-currency accounts. Monetary values and quantities are never converted to floating point. With no open positions, the CLI prints `No open positions.` See the [M3 positions API coverage matrix](docs/api/positions.md).

Save the original JSON array instead of a summary:

```sh
mkdir -p output
chmod 700 output
stack exec -- kirke positions --out output/positions.json
```

The destination directory must exist. The file is written privately using the same atomic replacement mechanism as `account --out` (owner-only file permissions on Unix). Position JSON and summaries may contain sensitive portfolio data, so do not share them publicly.

Official API documentation: [GET /v2/positions](https://docs.alpaca.markets/us/reference/getallopenpositions).

## Assets: crypto by default

List available crypto assets:

```sh
stack exec -- kirke assets
```

Unlike Alpaca's default behavior (which returns US equities when the asset class is omitted), Kirke sends **`asset_class=crypto` explicitly**. You can select equities and filter by status:

```sh
stack exec -- kirke assets --asset-class us_equity
stack exec -- kirke assets --status active
stack exec -- kirke assets --asset-class crypto --status inactive
stack exec -- kirke assets --status all
```

`--asset-class` supports every documented Alpaca class: `us_equity`, `us_option`, `crypto` (Kirke default), `crypto_perp`, `treasury`, `corporate`, `global_equity`, `us_index`, `us_equity_chain`, and `ipo`. `--status` accepts `active`, `inactive`, or `all`; if omitted, no status filter is sent.

Additional filters:

```sh
stack exec -- kirke assets --asset-class us_equity --exchange NASDAQ,NYSE --attributes has_options,overnight_tradable
stack exec -- kirke assets --asset-class us_index --exchange INDEX
stack exec -- kirke assets --asset-class us_equity --attributes ptp_no_exception,ipo --out output/assets.json
```

`--exchange` accepts comma-separated equity exchanges (AMEX, ARCA, BATS, NYSE, NASDAQ, NYSEARCA, OTC, TXSE) or `INDEX` **only for us_index**. Exchange filtering is rejected for crypto and other non-equity/index classes, rather than silently ignored. `--attributes` supports the eight documented attributes: `ptp_no_exception`, `ptp_with_exception`, `ipo`, `has_options`, `options_late_close`, `fractional_eh_enabled`, `overnight_tradable`, `overnight_halted`. Multiple attributes have **OR** semantics on Alpaca (any match). Empty, duplicated or unknown CSV entries are rejected.

The typed asset response covers all 19 documented fields, including venue, class/status/attribute enums, borrow status, marginability, shortability, fractional eligibility, exact decimal strings and nullable metadata. The human-readable summary remains concise and shows the required symbol, name, class, status, tradability, and fractionability. Empty results show `No matching assets.` See [assets API coverage](docs/api/assets.md).

Save the original, complete JSON array instead of a summary:

```sh
mkdir -p output
chmod 700 output
stack exec -- kirke assets --asset-class crypto --status active --out output/assets.json
```

Like the other `--out` commands, output uses an atomic write with owner-only file permissions (typically `0600` on Unix). The target directory must exist and the JSON remains unchanged, including provider fields beyond those displayed in the summary. No orders are submitted.

Official API documentation: [GET /v2/assets](https://docs.alpaca.markets/us/reference/get-v2-assets-1).

## Orders: read-only history and filters

List open orders (Alpaca defaults to open, 50 orders, newest first; Kirke sends the status and direction explicitly):

```sh
stack exec -- kirke orders
stack exec -- kirke orders --status all --limit 10
stack exec -- kirke orders --status closed --direction asc
stack exec -- kirke orders --symbols BTCUSD,ETHUSD,AAPL --limit 50
```

Options: `--status open|closed|all` (default open), `--limit 1..500` (provider default 50), `--direction asc|desc` (default desc), and `--symbols` with comma-separated trading symbols such as `BTCUSD` (not `BTC/USD`). Kirke also supports all documented order filters: `--after` and `--until` (exclusive submission-time RFC3339 bounds), `--nested`, `--side buy|sell`, `--asset-class` with a comma-separated list of the ten documented asset classes (or `all`), and exclusive order pagination with `--before-order-id UUID` or `--after-order-id UUID`. The two UUID anchors cannot be combined or mixed with timestamp bounds. Invalid combinations are rejected before credentials are loaded.

Examples:

```sh
stack exec -- kirke orders --status all --limit 10 --nested --side buy --asset-class crypto
stack exec -- kirke orders --status all --asset-class crypto,us_equity \
  --after 2026-11-01T00:00:00Z --until 2026-11-14T00:00:00Z
stack exec -- kirke orders --status all --limit 10 \
  --before-order-id 9275f66a-0a1b-4a22-8c55-167416c7cf14
```

The UUID is an example; use an existing order's server-issued `id`, not `client_order_id`. This endpoint does **not** have a page token, and Kirke does not automatically paginate. It prints `No matching orders.` for an empty result. Prices and quantities remain exact decimal **strings**, including optional/notional orders; null fields appear as `not provided`. The response decoder now models published common and leg-specific order fields, including six forward-compatible typed enums, partial fills and nested options with exact `ratio_qty`. Readable summaries include nested leg counts and ratios; `--out` still preserves all original JSON bytes, including unknown future properties. See the [M3 request coverage](docs/api/orders.md) and [response-field matrix](docs/api/orders-response.md).

Save the complete original provider response instead of displaying a summary:

```sh
stack exec -- kirke orders --status all --limit 10 --out output/orders.json
```

JSON files are private and atomically replaced (typically mode `0600`). Both summaries and order JSON can reveal personal portfolio activity. **No order is placed, modified or canceled.** The cursor flags provide explicit page-by-page navigation; automatic iteration over multiple pages remains a possible later improvement. Reference: [Alpaca GET /v2/orders](https://docs.alpaca.markets/us/reference/getallorders-1).

## Order details: fetch by server UUID

Look up a single order using the **server-issued UUID** (the `id` field in `kirke orders --out`, not `client_order_id`):

```sh
stack exec -- kirke order get 9275f66a-0a1b-4a22-8c55-167416c7cf14
stack exec -- kirke order get 9275f66a-0a1b-4a22-8c55-167416c7cf14 --nested
stack exec -- kirke order get 9275f66a-0a1b-4a22-8c55-167416c7cf14 --out output/order.json
```

The UUID above is an **illustrative placeholder**, not a real order. Use an ID from your paper account. Kirke validates canonical UUID syntax before sending a request, and `--nested` adds Alpaca's optional `nested=true` parameter, which rolls up multi-leg orders. Without `--nested`, no query parameter is sent. A missing order produces a distinct `HTTP 404` diagnostic; other HTTP, credential, connection and invalid-JSON failures remain separate. A successful response is an **order object**, not an array. Kirke now verifies that the returned order ID matches the requested UUID (case-insensitive hex), rejecting mismatches without revealing either identifier. Malformed responses are reported without disclosing provider JSON. The readable view reuses the same complete typed order decoder as the listing endpoint, preserving decimal strings and nullable values, including typed multi-leg option children. JSON output preserves the complete provider object, including nested `legs` when supplied, and uses the same private atomic writer as other commands. See the [M3 order-by-ID coverage matrix](docs/api/order-by-id.md).

This command is read-only and calls only the **paper trading** API. It never submits, modifies or cancels an order. API reference: [GET /v2/orders/{order_id}](https://docs.alpaca.markets/us/reference/getorderbyorderid-1).

## Submit a crypto paper order (dry run by default)

**Paper trading only.** The new `kirke order submit` command prepares a validated crypto market or limit order. Without `--confirm`, it **only prints the JSON request**: no credentials are loaded and no POST is sent.

```sh
# Preview without credentials or network (no order placed)
stack exec -- kirke order submit --symbol BTC/USD --side buy --type market --qty 0.0001 --client-order-id experiment-btc-001

# Preview a GTC limit order
stack exec -- kirke order submit --symbol BTC/USD --side buy --type limit --qty 0.0001 --limit-price 65000.00 --client-order-id experiment-limit-001

# Explicitly submit ONE order to the paper Trading API
stack exec -- kirke order submit --symbol BTC/USD --side buy --type market --qty 0.0001 --client-order-id experiment-btc-001 --confirm
```

A confirmed order can use `--out output/order.json` to save the validated response as private original JSON. The CLI requires `--client-order-id` for stable request identity; reusing it **does not** provide guaranteed idempotency. After a network timeout or server failure, check existing paper orders before retrying. A successful POST does **not** mean the order is filled.

Supported: crypto pairs, `buy|sell`, `market|limit`, `gtc|ioc` (default `gtc`), one of `--qty` or market-only `--notional`, plus limit-only `--limit-price`. Amounts are positive decimal **strings**, never floating-point; USD-quoted notional is capped at two decimal places. Asset-specific size/price increments and buying power are checked by Alpaca. See [full order submission contract, failure handling and safety rules](docs/api/order-submit.md).

**No live trading**, no stop/bracket/options submissions, no implicit retries, and no orders are placed by tests or the private read-only integration script.

## Historical crypto bars (Alpaca market-data API)

Historical bars use a separate read-only endpoint at **`https://data.alpaca.markets/v1beta3/crypto/{loc}/bars`**, authenticated using the same API-key environment variables. This is **not** the paper-trading endpoint. The historical bars command never places orders.

```sh
stack exec -- kirke crypto bars \
  --symbols BTC/USD,ETH/USD,SOL/USD --timeframe 1Hour \
  --start 2026-10-02T00:00:00Z --end 2026-10-03T00:00:00Z

stack exec -- kirke crypto bars \
  --symbols BTC/USD,ETH/USD --timeframe 5Min \
  --start 2026-10-02 --end 2026-10-03 \
  --limit 100 --max-pages 3 --sort asc --out output/crypto-bars.json

stack exec -- kirke crypto bars \
  --symbols SOL/USD --timeframe 1Min --limit 100 --max-pages 2 \
  --format jsonl --out output/sol-bars.jsonl
```

**Required:** `--symbols` is a comma-separated list of 1–30 crypto pairs such as `BTC/USD`; `--timeframe` accepts Alpaca's documented timeframes (1–59 minutes, 1–23 hours, 1 day, 1 week, or 1/2/3/4/6/12 months and their documented short aliases). Optional filters are `--location us|us-1|us-2|eu-1|bs-1` (default `us`), `--start` and `--end` (inclusive YYYY-MM-DD or RFC3339 timestamps with timezone), `--limit 1..10000` (default 1000, *across all symbols*, not per symbol), `--sort asc|desc` (default `asc`), `--page-token` to resume, and `--max-pages 1..20` (default **1**). The API may return fewer bars than the page limit even if more pages exist: always consider its next-page token. [Alpaca historical bars API reference](https://docs.alpaca.markets/us/reference/cryptobars-1).

**Output:** With no `--out`, the default `--format json` prints a concise summary and a remaining-pages indicator. With `--out PATH`, JSON output is a stable `{"pages":[API_PAGE_1,API_PAGE_2,...], "next_page_token":...}` document containing the complete original API response objects (including unrecognized fields), rather than disguising multiple pages as one provider response. A non-null final token means more pages remain; pass it via `--page-token` to resume. With `--format jsonl`, output is one JSON object per bar with `symbol`, `t`, `o`, `h`, `l`, `c`, `v`, `n`, `vw`. JSONL can be printed to stdout or written using `--out`. It does **not** retain the continuation token; use JSON export if you need resumption.

The typed decoder uses exact **Scientific decimal** values (no binary floating-point rounding); raw timestamps preserve the API's original nanosecond strings. JSON page objects retain additional upstream fields, although whitespace and numeric spelling may be normalized when serialized. File exports use atomic replacement and owner-only permissions, normally `0600`, and the parent directory must already exist. Bad dates, symbols, timeframes and page limits fail before networking. A repeated page token is rejected instead of looping indefinitely. This is only a small data-access client; Metis/Ariadne handle coverage planning and bulk backfill.

## Historical crypto trades (Alpaca market-data API)

Individual executions come from **`GET https://data.alpaca.markets/v1beta3/crypto/{loc}/trades`**, using the same credentials and read-only market-data host as bars. Unlike bars, **there is no timeframe argument**.

```sh
stack exec -- kirke crypto trades \
  --symbols BTC/USD,ETH/USD,SOL/USD \
  --start 2026-10-02T00:00:00Z --end 2026-10-03T00:00:00Z

stack exec -- kirke crypto trades \
  --symbols BTC/USD,ETH/USD --location us --limit 100 \
  --max-pages 3 --sort asc --out output/crypto-trades.json

stack exec -- kirke crypto trades \
  --symbols BTC/USD --limit 1000 --max-pages 2 \
  --format jsonl --out output/btc-trades.jsonl
```

**Filters:** `--symbols` (required, 1–30 comma-separated pairs like `BTC/USD`), `--location us|us-1|us-2|eu-1|bs-1` (default `us`), inclusive `--start` and `--end` (YYYY-MM-DD or RFC3339 with an explicit timezone), `--limit 1..10000` (default 1000 **across all symbols**), `--sort asc|desc` (default `asc`), `--max-pages 1..20` (default **1**), and optional `--page-token` to continue. A short page does not imply completion: check `next_page_token`. See [Alpaca historical trades API](https://docs.alpaca.markets/us/reference/cryptotrades-1).

**Output:** By default a human-readable summary reports page and trade counts per symbol, and whether a continuation token remains. With `--out PATH`, the default `--format json` produces `{"pages":[API_PAGE_1,API_PAGE_2,...],"next_page_token":...}`: complete API page objects, including undocumented fields, plus the final continuation token. Resume a later invocation with `--page-token`. With `--format jsonl`, stdout or `--out PATH` contains one JSON record per trade with `symbol`, `i` (integer trade ID), `p` (price), `s` (size), `t` (timestamp), and `tks` (taker side or null). JSONL does **not** contain a continuation token; choose JSON for resumable extraction.

Prices and sizes use Haskell `Scientific` and trade IDs `Integer`, preserving numeric precision without binary floating point. Timestamps retain all fractional digits, including nanoseconds. Original provider JSON fields survive in the JSON page envelopes, though serialization may normalize whitespace and numeric spelling. The command **processes one API page at a time**; summaries and file writes do not accumulate historical trades in memory. Output files are atomically replaced with owner-only permissions (typically `0600`); if any later page fails, the previous destination is left untouched. JSONL directed to stdout may already have printed earlier pages if a later request fails. For reliable exports use `--out` and an existing parent directory.

This is a bounded API client, not Ariadne/Metis backfill orchestration or trade execution. **No order is submitted or modified.**

## Historical crypto quotes (Alpaca market-data API)

Best bid/ask observations come from **`GET https://data.alpaca.markets/v1beta3/crypto/{loc}/quotes`**. Like historical trades, quote events have **no timeframe**, are read-only, and use the authenticated crypto market-data host.

```sh
stack exec -- kirke crypto quotes \
  --symbols BTC/USD,ETH/USD --start 2026-10-02T00:00:00Z \
  --end 2026-10-03T00:00:00Z

stack exec -- kirke crypto quotes \
  --symbols BTC/USD,SOL/USD --limit 500 --max-pages 3 \
  --out output/quotes.json

stack exec -- kirke crypto quotes \
  --symbols BTC/USD --limit 1000 --max-pages 2 --format jsonl \
  --out output/btc-quotes.jsonl
```

**Filters:** required `--symbols` (1–30 pairs), `--location us|us-1|us-2|eu-1|bs-1` (default `us`), inclusive `--start`/`--end` as a date or RFC3339 timestamp, `--limit 1..10000` (default 1000 **total across symbols per page**), `--sort asc|desc` (default `asc`), `--max-pages 1..20` (default 1), and optional `--page-token`. A short page is not the end of history when Alpaca supplies another token.

**Output:** With no `--out`, the default shows a per-symbol quote and page summary. Private JSON export contains `{"pages":[API_PAGE_1,...],"next_page_token":...}`, preserving known and unknown provider properties. JSONL contains one record per quote: `symbol`, `ap` (ask price), `as` (ask size), `bp` (bid price), `bs` (bid size) and `t` (exact timestamp text). Both sizes are measured in the **base asset**; no lot-size multiplier is applied. JSONL does not retain continuation tokens or unknown extension fields.

Bid/ask prices and sizes are `Scientific` exact decimal values, without binary floating-point rounding; numeric notation may be normalized during JSON serialization. Timestamp strings retain fractional seconds, including nanoseconds. Quotes are streamed **one page at a time**; failures on subsequent pages do not replace an existing private `--out` file. Files are written with owner-only permissions, normally `0600`. Streaming JSONL to stdout cannot be rolled back; use `--out` for atomic exports.

See the [Historical quotes API coverage matrix](docs/api/crypto-quotes.md). This is bounded retrieval, not full Ariadne/Metis backfill planning.

## Integration test (maintainers)

`scripts/cd.sh` performs live requests against the paper Trading API and read-only crypto Market Data API. It loads a trusted credentials file from `${XDG_CONFIG_HOME:-$HOME/.config}/kirke/credentials`, installs the local CLI using Stack, writes account, positions, assets, orders, and small crypto-bars, crypto-trades and crypto-quotes samples under the ignored `output/` directory, checks JSON structures using `jq`, and verifies private file permissions using GNU `stat`.

On a trusted Linux machine with paper credentials, `jq`, and Stack's executable directory on `PATH`:

```sh
./scripts/cd.sh
```

This is **not** run by public CI; CI uses only offline tests.

## Development and roadmap

Work is tracked in [GitHub Issues](https://github.com/black-belt-badger/kirke/issues) and pull requests. The initial [v0.1.0.0 release](https://github.com/black-belt-badger/kirke/releases/tag/v0.1.0.0) was paper-account-only; subsequent releases add read-only trading state and market data. Versions follow the [Haskell Package Versioning Policy](https://pvp.haskell.org/).

A separate, publicly released Rust implementation called [**Medea**](https://github.com/black-belt-badger/medea) follows the same outward behavior using idiomatic Rust code and independent versioning. Endpoint parity is implemented incrementally: Haskell first, then Rust.

## Visual identity

<img src="docs/color.png" alt="Kirke — small color icon" width="40" height="40">

The logo, illustrations, and source images are documented in [Branding and asset usage](docs/BRANDING.md). They are project-specific, AI-assisted artwork selected by the maintainer, **not** official Alpaca artwork or a mark of affiliation. The README banner uses an optimized WebP display copy while the original images remain committed.

## Contributing and security

Contributions, bug reports, and proposals are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) and use the issue templates. For private vulnerability reporting, **do not open a public issue**: follow [SECURITY.md](SECURITY.md).

This repository uses the [BSD 3-Clause License](LICENSE). It is a community project and is **not** an official Alpaca SDK.

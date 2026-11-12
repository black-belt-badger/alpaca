<p align="center">
  <img src="docs/fancy.png" alt="Kirke — Celtic-knot logo and wordmark" width="760">
</p>

# Kirke — Haskell CLI for Alpaca's paper Trading API

[![Haskell CI](https://github.com/black-belt-badger/kirke/actions/workflows/haskell-ci.yml/badge.svg)](https://github.com/black-belt-badger/kirke/actions/workflows/haskell-ci.yml)
[![License: BSD-3-Clause](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](LICENSE)

**Kirke** is an open-source, unofficial Haskell command-line application for accessing [Alpaca's Trading API](https://docs.alpaca.markets/). It offers **read-only account information, open positions, asset discovery, and order history** from Alpaca paper trading. It is not affiliated with, sponsored by, or endorsed by Alpaca Markets.

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
| `kirke orders` | List open paper orders, most recent first |
| `kirke orders --status all --limit 10` | Inspect up to 10 recent orders |
| `kirke orders --symbols BTCUSD,ETHUSD --direction asc` | Filter orders by symbol and submission order |
| `kirke orders --out PATH` | Save complete, unmodified order JSON privately |

The summary includes account number, status, currency, cash, equity, buying power, trading-blocked flag, and crypto status (when available).

**Not implemented:** live-account access, order submission/cancellation, market data, streaming, and shell completion. Listing positions does **not** close them or place orders. No trading decisions are made or orders placed.

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

The response includes crypto and equity positions together. Each row shows the symbol, asset class, long/short side, exact quantity, and market value, current price, and unrealized P/L when supplied. Monetary values and quantities are preserved as strings; there is no floating-point rounding. With no open positions, the CLI prints `No open positions.`

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

`--asset-class` accepts `crypto` (default) or `us_equity`. `--status` accepts `active`, `inactive`, or `all`; if omitted, no status filter is sent. Assets include their symbol, name when available, class, status, tradability, and fractional-trading eligibility where provided. Missing optional fields are displayed as `not provided`. Empty results show `No matching assets.`

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

Options: `--status open|closed|all`, `--limit 1..500`, `--direction asc|desc`, and `--symbols` with comma-separated API symbols such as `BTCUSD` (not `BTC/USD`). The filters are sent to Alpaca; Kirke does not paginate automatically. It prints `No matching orders.` for an empty result. Prices and quantities remain exact decimal **strings**, including optional/notional orders; null fields appear as `not provided`.

Save the complete original provider response instead of displaying a summary:

```sh
stack exec -- kirke orders --status all --limit 10 --out output/orders.json
```

JSON files are private and atomically replaced (typically mode `0600`). Both summaries and order JSON can reveal personal portfolio activity. **No order is placed, modified or canceled.** For historical queries beyond the latest 500, a future ticket will provide explicit pagination. Reference: [Alpaca GET /v2/orders](https://docs.alpaca.markets/us/reference/getallorders-1).

## Integration test (maintainers)

`scripts/it.sh` performs live requests against the **paper** API. It loads a trusted credentials file from `${XDG_CONFIG_HOME:-$HOME/.config}/kirke/credentials`, installs the local CLI using Stack, writes account, positions, assets, and orders files under the ignored `output/` directory, checks JSON structures using `jq`, and verifies private file permissions using GNU `stat`.

On a trusted Linux machine with paper credentials, `jq`, and Stack's executable directory on `PATH`:

```sh
./scripts/it.sh
```

This is **not** run by public CI; CI uses only offline tests.

## Development and roadmap

Work is tracked in [GitHub Issues](https://github.com/black-belt-badger/kirke/issues) and pull requests. The first release milestone is [v0.1.0.0](https://github.com/black-belt-badger/kirke/milestone/1); versions follow the [Haskell Package Versioning Policy](https://pvp.haskell.org/).

A separate, publicly released Rust implementation called [**Medea**](https://github.com/black-belt-badger/medea) follows the same outward behavior using idiomatic Rust code and independent versioning. Endpoint parity is implemented incrementally: Haskell first, then Rust.

## Contributing and security

Contributions, bug reports, and proposals are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) and use the issue templates. For private vulnerability reporting, **do not open a public issue**: follow [SECURITY.md](SECURITY.md).

This repository uses the [BSD 3-Clause License](LICENSE). It is a community project and is **not** an official Alpaca SDK.

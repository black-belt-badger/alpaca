# Changelog for `kirke`

All notable changes to this project will be documented here.

This project follows the [Haskell Package Versioning Policy](https://pvp.haskell.org/).
Release headings are dated only when a release is published.

## Unreleased

### Changed
- Model both `account.status` and optional `account.crypto_status` as a shared, forward-compatible `AccountStatus` enum; unknown future strings round-trip without changing CLI summaries or raw account JSON exports.

## 0.2.0.0 — 2026-11-13

### Added
- `kirke crypto trades` fetches bounded historical crypto executions with typed symbol, location, timestamp, limit, sort and token-based pagination filters, sharing the market-data request builder with bars.
- `Integer` trade IDs, exact-decimal `Scientific` prices and sizes, nanosecond timestamp strings and optional taker side; streaming JSONL/JSON page-envelope exports use owner-only atomic files and roll back on later-page errors.
- `kirke crypto bars` fetches authenticated historical crypto OHLCV bars with explicit symbols, location, timeframe, date bounds, page size, sorting and bounded token-based pagination.
- Typed, lossless-decimal Scientific bars, nanosecond timestamp strings, complete JSON page-envelope export, JSONL bar records, private output and offline/live integration tests.
- `kirke order get ORDER_ID` fetches one paper order using a validated UUID, with optional `--nested` and private `--out PATH` for complete JSON.
- The single-order command shares the typed order decoder and display fields, distinguishes HTTP 404 from authentication/transport failures, and has offline and paper API tests.
- `kirke orders` lists paper orders with typed status, limit, symbols and direction filters, maintaining exact decimal-string financial values.
- `kirke orders --out PATH` saves full provider JSON privately; offline and paper integration checks cover queries, null/empty results, and secure output.
- `kirke assets` lists crypto assets by default; `--asset-class` and `--status` control server-side filters.
- `kirke assets --out PATH` saves complete assets JSON privately, with tests for query construction, decoding, optional fields, and empty results.
- `kirke positions` lists all open crypto and equity positions from the Alpaca paper Trading API, preserving decimal strings.
- `kirke positions --out PATH` saves complete positions JSON with owner-only permissions.
- Offline tests for list decoding, null/missing optional fields, malformed data, safe HTTP handling, and private output.

### Changed
- Shared the paper-only authenticated HTTP request and private JSON file writer between account and positions commands.

## 0.1.0.0 — 2026-11-12

### Added
- First public preview of **Kirke**, an unofficial Haskell CLI for Alpaca's **paper trading** API.
- `kirke account` fetches a paper account and prints a readable summary.
- `kirke account --out PATH` saves the complete API JSON response using private file permissions.
- Environment-based credentials, explicit connection/HTTP errors, and a paper-only API endpoint.
- Offline Hspec tests, GitHub Actions CI, and an optional private paper-account integration check.
- Public build instructions, contribution templates, release procedure, security reporting policy, and BSD-3-Clause license.

### Limitations
- Read-only paper-account access only: no live trading, order placement, market data, or streaming.
- GitHub source release only; no prebuilt binaries or Hackage publication in this version.

# Changelog for `kirke`

All notable changes to this project will be documented here.

This project follows the [Haskell Package Versioning Policy](https://pvp.haskell.org/).
Release headings are dated only when a release is published.

## Unreleased

No changes yet.

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

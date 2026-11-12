# Alpaca — Haskell CLI for Alpaca's paper Trading API

[![Haskell CI](https://github.com/black-belt-badger/alpaca/actions/workflows/haskell-ci.yml/badge.svg)](https://github.com/black-belt-badger/alpaca/actions/workflows/haskell-ci.yml)
[![License: BSD-3-Clause](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](LICENSE)

**Alpaca** is an open-source, unofficial Haskell command-line application for accessing [Alpaca's Trading API](https://docs.alpaca.markets/). It currently offers **read-only access to a paper trading account**. It is not affiliated with, sponsored by, or endorsed by Alpaca Markets.

The project is early in development. Its first goal is a small, useful, testable CLI; additional commands may follow as separate issues.

## Current functionality

| Command | Behavior |
| --- | --- |
| `alpaca --help` | List commands and general options |
| `alpaca account --help` | Show account-specific options |
| `alpaca account` | Fetch a paper account and print a readable summary |
| `alpaca account --out PATH` | Fetch a paper account and save the complete API JSON response |

The summary includes account number, status, currency, cash, equity, buying power, trading-blocked flag, and crypto status (when available).

**Not implemented:** live-account access, trade submission, order management, market data, streaming, and shell completion. No trading decisions are made or orders placed.

## Requirements

- Linux or another compatible Unix-like system (Unix permissions are part of the output-file behavior and test suite).
- [GHC](https://www.haskell.org/ghc/) **9.10.3** installed.
- [Stack](https://docs.haskellstack.org/) **3.11.1** (the version used for development and CI).
- An [Alpaca paper trading account](https://alpaca.markets/) with **paper API credentials** for authenticated commands.

The repository pins a Stackage snapshot in `stack.yaml` and tracks `stack.yaml.lock`. Its configuration expects a locally installed GHC; Stack does not automatically install one.

## Build and test

```sh
git clone https://github.com/black-belt-badger/alpaca.git
cd alpaca
stack build
stack test
stack exec -- alpaca --help
```

Offline tests do **not** require an Alpaca account or credentials. The same build and test commands run in [GitHub Actions CI](https://github.com/black-belt-badger/alpaca/actions).

For local installation instead of `stack exec`, run `stack install` and make sure Stack's executable installation directory is on your `PATH`.

## Configure paper credentials

Alpaca authenticates the paper account request using two environment variables:

- `APCA_API_KEY_ID`
- `APCA_API_SECRET_KEY`

The application sends them as HTTP headers over HTTPS to **`https://paper-api.alpaca.markets/v2/account`**. It does not use the live trading endpoint.

For interactive use, you can source a private credentials file **outside this repository**. On Linux:

```sh
install -d -m 700 "$HOME/.config/alpaca"
umask 077
${EDITOR:-vi} "$HOME/.config/alpaca/credentials"
chmod 600 "$HOME/.config/alpaca/credentials"
```

Put the following lines in that file, replacing only the obvious placeholders with your **paper** credentials:

```sh
export APCA_API_KEY_ID="YOUR_PAPER_KEY_ID"
export APCA_API_SECRET_KEY="YOUR_PAPER_SECRET_KEY"
```

Load them into your shell before calling the CLI:

```sh
source "$HOME/.config/alpaca/credentials"
```

Only source a credentials file you created and trust. Don't paste real credentials into issues, PRs, screenshots, shell commands saved in history, CI logs, or the repository. You can also provide these environment variables by other secure means; no specific file location is required by the application.

For a nondefault config location, the developer-only integration script respects `XDG_CONFIG_HOME`.

## Usage

Print your paper account summary:

```sh
stack exec -- alpaca account
```

Illustrative output (account details deliberately omitted):

```text
Alpaca paper account
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
stack exec -- alpaca account --out output/account.json
```

On Unix, the CLI writes through a private temporary file and atomically replaces the destination, resulting in owner-only file permissions (typically `0600`). The parent directory must already exist. Use a private directory; the full API response can contain additional sensitive account data.

Files in `output/` are ignored by Git. Do not publish them.

## Integration test (maintainers)

`scripts/it.sh` performs live requests against the **paper** API. It loads a trusted credentials file from `${XDG_CONFIG_HOME:-$HOME/.config}/alpaca/credentials`, installs the local CLI using Stack, writes files under the ignored `output/` directory, checks JSON fields using `jq`, and verifies private file permissions using GNU `stat`.

On a trusted Linux machine with paper credentials, `jq`, and Stack's executable directory on `PATH`:

```sh
./scripts/it.sh
```

This is **not** run by public CI; CI uses only offline tests.

## Development and roadmap

Work is tracked in [GitHub Issues](https://github.com/black-belt-badger/alpaca/issues) and pull requests. The first release milestone is [v0.1.0.0](https://github.com/black-belt-badger/alpaca/milestone/1); versions follow the [Haskell Package Versioning Policy](https://pvp.haskell.org/).

A separate Rust implementation called **Medea** is planned to reproduce the same outward behavior with idiomatic Rust code and independent versioning. It is not yet publicly available. Feature parity is a learning and compatibility goal, not a guarantee that both projects already expose the same functionality.

## Contributing and security

Contributions, bug reports, and proposals are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) and use the issue templates. For private vulnerability reporting, **do not open a public issue**: follow [SECURITY.md](SECURITY.md).

This repository uses the [BSD 3-Clause License](LICENSE). It is a community project and is **not** an official Alpaca SDK.

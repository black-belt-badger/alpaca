#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

umask 077
mkdir -p output

# Load local paper-trading credentials without placing them in the repository.
source "${XDG_CONFIG_HOME:-$HOME/.config}/alpaca/credentials"

stack install

alpaca --help
alpaca account --help
alpaca account
alpaca account --out ./output/account.json

echo "CLI smoke checks passed (account fetching not implemented yet)"
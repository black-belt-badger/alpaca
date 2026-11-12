#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

umask 077
mkdir -p output

stack install

alpaca --help
alpaca account --help
alpaca account
alpaca account --out ./output/account.json

echo "CLI smoke checks passed (account fetching not implemented yet)"
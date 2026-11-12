#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

umask 077
mkdir -p output
chmod 700 output

# Load local paper-trading credentials without placing them in the repository.
source "${XDG_CONFIG_HOME:-$HOME/.config}/kirke/credentials"

stack install

kirke --help
kirke account --help
kirke account > ./output/account-summary.txt
kirke account --out ./output/account.json

test -s ./output/account-summary.txt
grep -q '^Kirke — Alpaca paper account$' ./output/account-summary.txt
test -s ./output/account.json
jq -e '.id and .status and .cash and .equity and .buying_power' ./output/account.json > /dev/null
test "$(stat -c '%a' ./output/account.json)" = 600

echo "Kirke: Alpaca paper API integration checks passed"

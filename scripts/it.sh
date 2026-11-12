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
kirke positions --help > /dev/null
kirke positions > ./output/positions-summary.txt
kirke positions --out ./output/positions.json > ./output/positions-written.txt
kirke assets --help > /dev/null
kirke assets --status active > ./output/assets-summary.txt
kirke assets --status active --out ./output/assets.json > ./output/assets-written.txt
kirke orders --help > /dev/null
kirke orders --status all --limit 10 > ./output/orders-summary.txt
kirke orders --status all --limit 10 --out ./output/orders.json > ./output/orders-written.txt

test -s ./output/account-summary.txt
grep -q '^Kirke — Alpaca paper account$' ./output/account-summary.txt
test -s ./output/account.json
jq -e '.id and .status and .cash and .equity and .buying_power' ./output/account.json > /dev/null
test "$(stat -c '%a' ./output/account.json)" = 600

test -s ./output/positions-summary.txt
grep -q '^Kirke — Alpaca paper positions$' ./output/positions-summary.txt
jq -e 'type == "array"' ./output/positions.json > /dev/null
test "$(stat -c '%a' ./output/positions.json)" = 600
test "$(stat -c '%a' ./output/positions-summary.txt)" = 600

test -s ./output/assets-summary.txt
grep -q '^Kirke — Alpaca paper assets$' ./output/assets-summary.txt
jq -e 'type == "array" and all(.[]; .class == "crypto" and (.tradable | type == "boolean"))' ./output/assets.json > /dev/null
test "$(stat -c '%a' ./output/assets.json)" = 600
test "$(stat -c '%a' ./output/assets-summary.txt)" = 600

test -s ./output/orders-summary.txt
grep -q '^Kirke — Alpaca paper orders$' ./output/orders-summary.txt
jq -e 'type == "array" and (length <= 10) and all(.[]; .id and .client_order_id and .symbol and .status)' ./output/orders.json > /dev/null
test "$(stat -c '%a' ./output/orders.json)" = 600
test "$(stat -c '%a' ./output/orders-summary.txt)" = 600

# A fresh paper account can legitimately have zero orders. When a previous
# order exists, use its server-issued ID to exercise the single-order endpoint.
kirke order --help > /dev/null
kirke order get --help > /dev/null
if jq -e 'length > 0' ./output/orders.json > /dev/null; then
  order_id="$(jq -r '.[0].id' ./output/orders.json)"
  kirke order get "$order_id" > ./output/order-summary.txt
  kirke order get "$order_id" --nested --out ./output/order.json > ./output/order-written.txt
  grep -q '^Kirke — Alpaca paper order$' ./output/order-summary.txt
  jq -e --arg id "$order_id" '.id == $id and .client_order_id and .symbol and .status' ./output/order.json > /dev/null
  test "$(stat -c '%a' ./output/order.json)" = 600
  test "$(stat -c '%a' ./output/order-summary.txt)" = 600
else
  echo 'Kirke: no paper orders available; skipping single-order API check'
fi

echo "Kirke: Alpaca paper API integration checks passed"

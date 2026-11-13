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
# Exercise M3 exchange + attribute filters together (read-only paper API).
kirke assets --asset-class us_equity --exchange NASDAQ --attributes has_options \
  --out ./output/assets-nasdaq-options.json > ./output/assets-nasdaq-options-written.txt
kirke orders --help > /dev/null
kirke orders --status all --limit 10 > ./output/orders-summary.txt
kirke orders --status all --limit 10 --out ./output/orders.json > ./output/orders-written.txt
# M3: exercise the documented side, multi-class and nested request filters.
kirke orders --status all --limit 10 --side buy --asset-class crypto --nested \
  --out ./output/orders-filtered.json > ./output/orders-filtered-written.txt

test -s ./output/account-summary.txt
grep -q '^Kirke — Alpaca paper account$' ./output/account-summary.txt
test -s ./output/account.json
jq -e '.id and .status and .cash and .equity and .buying_power' ./output/account.json > /dev/null
test "$(stat -c '%a' ./output/account.json)" = 600

test -s ./output/positions-summary.txt
grep -q '^Kirke — Alpaca paper positions$' ./output/positions-summary.txt
jq -e 'type == "array"' ./output/positions.json > /dev/null
# Required M3 positions fields must retain their documented wire types.
jq -e 'type == "array" and all(.[]; (.asset_id|type) == "string" and (.asset_class|type) == "string" and (.exchange|type) == "string" and (.qty|type) == "string" and (.market_value|type) == "string" and (.asset_marginable|type) == "boolean" and (.side|type) == "string")' ./output/positions.json > /dev/null
test "$(stat -c '%a' ./output/positions.json)" = 600
test "$(stat -c '%a' ./output/positions-summary.txt)" = 600

test -s ./output/assets-summary.txt
grep -q '^Kirke — Alpaca paper assets$' ./output/assets-summary.txt
jq -e 'type == "array" and all(.[]; .class == "crypto" and (.tradable | type == "boolean"))' ./output/assets.json > /dev/null
test "$(stat -c '%a' ./output/assets.json)" = 600
test "$(stat -c '%a' ./output/assets-summary.txt)" = 600
jq -e 'type == "array" and all(.[]; .class == "us_equity" and .exchange == "NASDAQ" and ((.attributes // []) | index("has_options") != null))' ./output/assets-nasdaq-options.json > /dev/null
test "$(stat -c '%a' ./output/assets-nasdaq-options.json)" = 600

test -s ./output/orders-summary.txt
grep -q '^Kirke — Alpaca paper orders$' ./output/orders-summary.txt
jq -e 'type == "array" and (length <= 10) and all(.[]; .id and .client_order_id and .symbol and .status)' ./output/orders.json > /dev/null
test "$(stat -c '%a' ./output/orders.json)" = 600
test "$(stat -c '%a' ./output/orders-summary.txt)" = 600
jq -e 'type == "array" and (length <= 10) and all(.[]; .side == "buy" and .asset_class == "crypto")' ./output/orders-filtered.json > /dev/null
test "$(stat -c '%a' ./output/orders-filtered.json)" = 600

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

kirke crypto --help > /dev/null
kirke crypto bars --help > /dev/null
# A bounded historical sample: 2 symbols, at most two pages of two bars each.
crypto_flags=(--symbols BTC/USD,ETH/USD --timeframe 1Hour \
  --start 2026-10-02T00:00:00Z --end 2026-10-02T03:00:00Z \
  --limit 2 --max-pages 2)
kirke crypto bars "${crypto_flags[@]}" > ./output/crypto-bars-summary.txt
kirke crypto bars "${crypto_flags[@]}" --out ./output/crypto-bars.json > ./output/crypto-bars-written.txt
kirke crypto bars "${crypto_flags[@]}" --format jsonl --out ./output/crypto-bars.jsonl > ./output/crypto-bars-jsonl-written.txt
grep -q '^Kirke — Alpaca historical crypto bars$' ./output/crypto-bars-summary.txt
jq -e '(.pages | type == "array" and length >= 1 and length <= 2) and (.next_page_token == null or (.next_page_token | type == "string"))' ./output/crypto-bars.json > /dev/null
jq -e 'all(.pages[]; (.bars | type == "object"))' ./output/crypto-bars.json > /dev/null
test "$(stat -c '%a' ./output/crypto-bars.json)" = 600
test "$(stat -c '%a' ./output/crypto-bars.jsonl)" = 600
test -s ./output/crypto-bars.jsonl
jq -e -c '.symbol and .t and (.o | type == "number") and (.v | type == "number")' ./output/crypto-bars.jsonl > /dev/null

# Historical individual trades: two symbols, up to two pages of two trades.
trades_flags=(--symbols BTC/USD,ETH/USD \
  --start 2026-10-02T00:00:00Z --end 2026-10-02T03:00:00Z \
  --limit 2 --max-pages 2)
kirke crypto trades --help > /dev/null
kirke crypto trades "${trades_flags[@]}" > ./output/crypto-trades-summary.txt
kirke crypto trades "${trades_flags[@]}" --out ./output/crypto-trades.json > ./output/crypto-trades-written.txt
kirke crypto trades "${trades_flags[@]}" --format jsonl --out ./output/crypto-trades.jsonl > ./output/crypto-trades-jsonl-written.txt
grep -q '^Kirke — Alpaca historical crypto trades$' ./output/crypto-trades-summary.txt
jq -e '(.pages | type == "array" and length >= 1 and length <= 2) and (.next_page_token == null or (.next_page_token | type == "string"))' ./output/crypto-trades.json > /dev/null
jq -e 'all(.pages[]; (.trades | type == "object"))' ./output/crypto-trades.json > /dev/null
test "$(stat -c '%a' ./output/crypto-trades.json)" = 600
test "$(stat -c '%a' ./output/crypto-trades.jsonl)" = 600
test -s ./output/crypto-trades.jsonl
jq -e -c '.symbol and .i and .t and (.p | type == "number") and (.s | type == "number")' ./output/crypto-trades.jsonl > /dev/null

# Historical best bid/ask quotes: two symbols, at most two pages of two records.
quotes_flags=(--symbols BTC/USD,ETH/USD \
  --start 2026-10-02T00:00:00Z --end 2026-10-02T03:00:00Z \
  --limit 2 --max-pages 2)
kirke crypto quotes --help > /dev/null
kirke crypto quotes "${quotes_flags[@]}" > ./output/crypto-quotes-summary.txt
kirke crypto quotes "${quotes_flags[@]}" --out ./output/crypto-quotes.json > ./output/crypto-quotes-written.txt
kirke crypto quotes "${quotes_flags[@]}" --format jsonl --out ./output/crypto-quotes.jsonl > ./output/crypto-quotes-jsonl-written.txt
grep -q '^Kirke — Alpaca historical crypto quotes$' ./output/crypto-quotes-summary.txt
jq -e '(.pages | type == "array" and length >= 1 and length <= 2) and
  (.next_page_token == null or (.next_page_token | type == "string")) and
  all(.pages[]; (.quotes | type == "object"))' ./output/crypto-quotes.json > /dev/null
test "$(stat -c '%a' ./output/crypto-quotes.json)" = 600
test "$(stat -c '%a' ./output/crypto-quotes.jsonl)" = 600
test -s ./output/crypto-quotes.jsonl
jq -e -c '.symbol and (.ap | type == "number") and (.as | type == "number") and
  (.bp | type == "number") and (.bs | type == "number") and
  (.t | type == "string")' ./output/crypto-quotes.jsonl > /dev/null

echo "Kirke: Alpaca paper and crypto market-data API integration checks passed"

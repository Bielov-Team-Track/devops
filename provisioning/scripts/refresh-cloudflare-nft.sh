#!/usr/bin/env bash
# Refresh the Cloudflare source-IP sets used to gate ports 80/443.
# Cloudflare's published ranges drift; a stale list silently rejects legitimate
# edge traffic. Applied as ONE nft transaction so the sets are never observed
# empty — a separate flush-then-add would briefly reject all inbound web
# traffic while the set was empty.
set -euo pipefail

v4=$(curl -fsS --max-time 20 https://www.cloudflare.com/ips-v4)
v6=$(curl -fsS --max-time 20 https://www.cloudflare.com/ips-v6)

# Refuse to apply a partial fetch: an empty set would reject all edge traffic.
[ -n "$v4" ] && [ -n "$v6" ] || { echo "empty fetch, aborting without changes" >&2; exit 1; }

v4_csv=$(printf '%s\n' "$v4" | grep -E '^[0-9]' | paste -sd, -)
v6_csv=$(printf '%s\n' "$v6" | grep -E '^[0-9a-fA-F:]' | paste -sd, -)

[ -n "$v4_csv" ] && [ -n "$v6_csv" ] || { echo "parsed to empty, aborting" >&2; exit 1; }

txn=$(mktemp)
trap 'rm -f "$txn"' EXIT
{
  echo "flush set inet volleyspike cloudflare_v4"
  echo "add element inet volleyspike cloudflare_v4 { $v4_csv }"
  echo "flush set inet volleyspike cloudflare_v6"
  echo "add element inet volleyspike cloudflare_v6 { $v6_csv }"
} > "$txn"

nft -f "$txn"

echo "refreshed: $(printf '%s\n' "$v4" | grep -cE '^[0-9]') v4, $(printf '%s\n' "$v6" | grep -cE '^[0-9a-fA-F:]') v6"

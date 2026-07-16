#!/usr/bin/env bash
# Agent-side walkthrough: wallet -> topup link -> (human pays) -> spend 1 cent -> audit.
set -euo pipefail
B=${PEAGE_URL:-https://peage.intrane.fr}

W=$(curl -s -X POST "$B/v1/wallets" -d '{"email":"'"${1:-operator@example.com}"'"}')
echo "$W"
TOK=$(echo "$W" | python3 -c "import json,sys; print(json.load(sys.stdin)['token'])")

echo "-- topup link (hand to your human, min 5 EUR):"
curl -s -X POST "$B/v1/topup" -H "Authorization: Bearer $TOK" -d '{"amount_cents":500}'
echo

echo "-- once funded, a 1-cent metered call:"
echo "curl -s $B/demo/fortune -H 'X-Peage-Wallet: $TOK'"
echo "-- balance & history:"
echo "curl -s $B/v1/wallet -H 'Authorization: Bearer $TOK'"

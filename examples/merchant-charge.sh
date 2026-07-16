#!/usr/bin/env bash
# Merchant-side walkthrough: register -> charge a wallet -> verify the receipt.
# usage: ./merchant-charge.sh payout@you.com pw_<caller wallet token>
set -euo pipefail
B=${PEAGE_URL:-https://peage.intrane.fr}
EMAIL=${1:?usage: merchant-charge.sh <payout email> <wallet token>}
WALLET=${2:?usage: merchant-charge.sh <payout email> <wallet token>}

M=$(curl -s -X POST "$B/v1/merchants" -d '{"email":"'"$EMAIL"'","name":"example api"}')
echo "$M"
KEY=$(echo "$M" | python3 -c "import json,sys; print(json.load(sys.stdin)['key'])")

echo "-- charging 2 cents (idempotent):"
CH=$(curl -s -X POST "$B/v1/charge" -H "Authorization: Bearer $KEY" \
  -d '{"wallet_token":"'"$WALLET"'","amount_cents":2,"memo":"example call","idempotency_key":"demo-1"}')
echo "$CH"

R=$(echo "$CH" | python3 -c "import json,sys; print(json.load(sys.stdin).get('receipt',''))")
echo "-- anyone can verify the receipt:"
curl -s "$B/v1/receipts?r=$R"
echo

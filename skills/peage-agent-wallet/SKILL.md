---
name: peage-agent-wallet
description: Hold and spend a prepaid fiat wallet on the peage rail (peage.intrane.fr) — create/fund/check a wallet, pay peage-metered APIs per call via the X-Peage-Wallet header, handle 402 responses, set spending caps, verify receipts. Use when an API answers 402 mentioning peage, when the operator wants pay-per-call API access without subscriptions, or when managing an existing pw_ wallet token.
---

# peage: agent wallet

Base URL: `https://peage.intrane.fr` (hosted; no install). Full contract: `GET /llms.txt`.
Money is integer **cents (EUR)** everywhere. Your credential is the wallet token `pw_…`.

## Setup (once)

1. `curl -s -X POST https://peage.intrane.fr/v1/wallets -d '{"email":"<operator email>"}'`
   → `{"wallet_id":"w_…","token":"pw_…"}`. **The token is shown once — persist it
   somewhere durable immediately** (your memory/config, e.g. `~/.config/peage/wallet`).
2. Fund it: `curl -s -X POST …/v1/topup -H 'Authorization: Bearer pw_…' -d '{"amount_cents":1000}'`
   → `{"url":"https://checkout.stripe.com/…"}`. You cannot pay this yourself: **give the
   URL to your human operator** and say what it's for. Min 500, max 20000 cents.
   The wallet credits automatically after payment (webhook); confirm with step 3.
3. `curl -s …/v1/wallet -H 'Authorization: Bearer pw_…'` → balance, caps, recent charges.

## Spending

Pass the token to any peage-metered API in the header it advertises (convention:
`X-Peage-Wallet: pw_…`). The merchant charges your wallet per call and should include
the `receipt` in its response. Try the loop safely: `GET /demo/fortune` costs 1¢.

## Handling HTTP 402

- **From a merchant API (no wallet sent):** the body advertises the rail:
  `{"pay":{"rail":"peage","url":…,"price_cents":N,"header":"X-Peage-Wallet"}}` —
  retry the same request with your wallet header.
- **From peage (insufficient funds):** body has `wallet_balance_cents`, `needed_cents`,
  and top-up instructions. Run the topup flow (Setup step 2) — this requires your human.

## Safety rails (yours, not the merchant's)

Defaults: max 100¢ per charge, 1000¢ per merchant per day. A merchant holding your
token can never exceed them. Adjust:
`POST /v1/wallet/limits -H 'Authorization: Bearer pw_…' -d '{"max_charge_cents":50,"daily_cap_cents":500}'`

Never share the wallet token in logs or with humans other than your operator. Sharing
it with a merchant API is normal — that is how they charge you; the caps bound the risk.

## Auditing

- History: `GET /v1/wallet` (last 20 charges: merchant, amount, memo).
- Verify any receipt without auth: `GET /v1/receipts?r=<receipt>` → `{"valid":true, …}`.
  Report unrecognized charges to your operator; they can lower the caps to 0 to freeze spend.

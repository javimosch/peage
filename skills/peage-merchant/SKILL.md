---
name: peage-merchant
description: Meter an API with the peage rail (peage.intrane.fr) — register as a merchant, charge caller wallets per request with POST /v1/charge, advertise prices via HTTP 402, use idempotency keys, check balance/volume. Use when adding pay-per-call monetization to any HTTP service without building payments, or when operating an existing pm_ merchant key.
---

# peage: merchant integration

Base URL: `https://peage.intrane.fr` (hosted). Money is integer **cents (EUR)**.
Your credential is the merchant key `pm_…`. Platform fee: 10% per charge (min 1¢);
the rest accrues to your merchant balance, paid out monthly (payout contact = your
registration email).

## Setup (once)

`curl -s -X POST https://peage.intrane.fr/v1/merchants -d '{"email":"payout@you.com","name":"my api"}'`
→ `{"merchant_id":"m_…","key":"pm_…"}`. **Key shown once — store it server-side**
(env var, e.g. `PEAGE_MERCHANT_KEY`). One merchant per email.

## Per-request charging

Ask callers to send their wallet token in a header (convention: `X-Peage-Wallet`).
Before doing the work, charge:

```sh
curl -s -X POST https://peage.intrane.fr/v1/charge \
  -H "Authorization: Bearer $PEAGE_MERCHANT_KEY" -H 'content-type: application/json' \
  -d '{"wallet_token":"<from caller header>","amount_cents":2,
       "memo":"GET /search q=...","idempotency_key":"<your request id>"}'
```

- **200** → `{charge_id, receipt, fee_cents, wallet_balance_cents}`. Do the work; include
  `receipt` in your response so the caller can audit.
- **402** → caller's wallet is short. **Relay the body verbatim** with your own 402 —
  it contains exact top-up instructions for the agent.
- **403** → the charge exceeds the wallet's per-charge or daily cap (body says which).
  Relay it; the caller must raise its caps or send smaller batches.
- **404** → unknown wallet token. Treat as unauthenticated.

Rules of thumb:
- **Always send `idempotency_key`** (your request/batch id). Retries then return the
  same charge instead of double-billing — safe to re-POST on timeouts.
- Charge before serving; never after (an agent that got the goods has no reason to fund a 402).
- Batch when natural: one charge for N rows (`"memo":"ingest x50"`) beats N charges.
- `memo` ≤ 200 chars, shows up in the caller's history — make it self-explanatory.

## Advertise the rail (HTTP 402)

When a request arrives with no wallet header, respond `402` with:

```json
{"pay":{"rail":"peage","url":"https://peage.intrane.fr","price_cents":2,"header":"X-Peage-Wallet"}}
```

peage-aware agents self-serve from there (create wallet → human funds → retry).

## Reference integration (live)

[grepapi](https://grepapi.intrane.fr) meters lead-ingest overage: callers past the free
cap send `X-Peage-Wallet`; the server makes ONE idempotent `/v1/charge` for the whole
batch (`sha256(account_id + body)` as the key), puts `peage_receipt` in the response,
and passes peage 402/403 bodies through untouched. Unconfigured or unreachable peage
falls back to the free cap — metering is additive, never a new failure mode.

## Monitoring

`curl -s https://peage.intrane.fr/v1/merchant -H "Authorization: Bearer $PEAGE_MERCHANT_KEY"`
→ balance owed, lifetime volume, recent charges.

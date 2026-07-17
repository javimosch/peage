# x402 binding: scheme `exact` on network `peage:eur`

**Status:** live (v0.5.0, 2026-07-17) · **Facilitator:** `https://peage.intrane.fr/x402`
**Follows:** x402 v2 (`x402-specification-v2.md`, 2025-12-09); v1 payloads accepted.
We track the canonical fiat-credit binding being drafted upstream (x402-foundation/x402
PR #2612) and will align naming when it merges.

peage is a prepaid fiat credit rail: wallets are funded by card (Stripe Checkout, EUR),
balances live on a publicly auditable ledger (`GET /v1/solvency`), and settlement is an
atomic balance decrement — the credit-backed trust model, no chain involved.

## PaymentRequirements (what a resource server advertises)

```json
{
  "scheme": "exact",
  "network": "peage:eur",
  "amount": "3",
  "asset": "EUR",
  "payTo": "merchant",
  "maxTimeoutSeconds": 60,
  "extra": { "facilitator": "https://peage.intrane.fr/x402" }
}
```

- `amount` — string, **EUR cents** (the smallest unit, per spec convention).
- `asset` — `"EUR"` (ISO 4217, as sanctioned by the v2 spec for fiat).
- `payTo` — the role constant `"merchant"`; the concrete recipient is resolved from the
  merchant key the resource server uses when calling the facilitator.

## Scheme payload (inside PAYMENT-SIGNATURE)

```json
{ "wallet_token": "pw_…", "idempotency_key": "req-123" }
```

- `wallet_token` — the caller's prepaid peage wallet (mint: `POST /v1/wallets`; fund:
  `POST /v1/topup` → Stripe Checkout URL for the caller's human).
- `idempotency_key` — optional but **strongly recommended**: a retried `/settle` with the
  same key returns the original settlement instead of double-billing. (Upstream leaves
  retry semantics unspecified — x402#452; in this binding idempotent settle is normative.)

No signature is required inside the payload: possession of the wallet token is the
authorization, and the caller's exposure is bounded wallet-side (per-charge cap +
per-merchant daily cap, set by the wallet holder — `POST /v1/wallet/limits`).

## Facilitator endpoints

Auth: `Authorization: Bearer <pm_… merchant key>` (register: `POST /v1/merchants`).

- `POST /x402/verify` — `{x402Version, paymentPayload, paymentRequirements}` →
  `{"isValid":true,"payer":"w_…"}` or `{"isValid":false,"invalidReason":"insufficient_funds"|…}`.
  Validation only; no money moves.
- `POST /x402/settle` — same request shape →
  `{"success":true,"transaction":"c_….<hmac>","network":"peage:eur","payer":"w_…","amount":"3"}`.
  `transaction` is a **signed receipt anyone can verify without auth**:
  `GET /v1/receipts?r=<transaction>`.
- `GET /x402/supported` — kinds: `exact` on `peage:eur`, x402Version 1 and 2.

Error enums map to the spec set: `invalid_x402_version`, `unsupported_scheme`,
`invalid_network`, `invalid_payload`, `invalid_payment_requirements`, `insufficient_funds`.

## Live demo (full header flow, curl-able)

```sh
# 1. bare request -> 402 with a PAYMENT-REQUIRED header (base64 v2 requirements)
curl -sD - https://peage.intrane.fr/demo/fortune -o /dev/null | grep -i payment-required

# 2. retry with PAYMENT-SIGNATURE (1 cent from a funded wallet)
PSIG=$(printf '{"x402Version":2,"payload":{"wallet_token":"pw_…","idempotency_key":"demo-1"}}' | base64 -w0)
curl -sD - https://peage.intrane.fr/demo/fortune -H "PAYMENT-SIGNATURE: $PSIG"
# -> 200 + fortune + PAYMENT-RESPONSE header with the signed receipt in `transaction`
```

## Notes for x402 implementers

- Variable-cost settlement (`upto` semantics) exists on the rail today as hold→capture
  (`POST /v1/holds` / `/v1/holds/capture`); exposing it as scheme `upto` on `peage:eur`
  is planned once we've aligned with the upstream fiat-credit binding.
- The ledger invariant behind every settlement is public: `GET /v1/solvency`.
- "x402" is a trademark of LF Projects, LLC; peage is an independent x402-compatible
  implementation, not affiliated with or endorsed by the x402 Foundation.

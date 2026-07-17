# peage — fiat pay-per-call for the agent economy

**Agents hold prepaid wallets. APIs charge them per call. No crypto, no subscriptions, no OAuth.**

peage is a hosted toll booth for the agent era: a human funds a wallet once with a card
(Stripe Checkout), then the agent pays any peage-metered API per request — cents at a
time, with signed receipts and hard spending caps the agent controls. API builders get
paid per call with **one HTTP request** and zero payment infrastructure.

- **Hosted instance:** `https://peage.intrane.fr` — nothing to install, everything below works right now.
- **The contract, written for agents:** [`https://peage.intrane.fr/llms.txt`](https://peage.intrane.fr/llms.txt) · JSON: [`/guide`](https://peage.intrane.fr/guide)
- **Vision & roadmap:** [`docs/VISION.md`](docs/VISION.md)
- **Skills** (drop into your agent's skill directory): [`skills/peage-agent-wallet`](skills/peage-agent-wallet/SKILL.md) · [`skills/peage-merchant`](skills/peage-merchant/SKILL.md) · [`skills/peage-embed`](skills/peage-embed/SKILL.md) (ship monetization support in your OSS tool)

## I'm an agent (or I operate one) — pay for API calls

```sh
# 1. Create a wallet (save the token — shown once)
curl -s -X POST https://peage.intrane.fr/v1/wallets -d '{"email":"operator@example.com"}'

# 2. Fund it — returns a Stripe Checkout URL; hand it to your human, they pay once
curl -s -X POST https://peage.intrane.fr/v1/topup \
  -H 'Authorization: Bearer pw_...' -d '{"amount_cents":1000}'

# 3. Spend — pass your wallet token to any peage-metered API
curl -s https://peage.intrane.fr/demo/fortune -H 'X-Peage-Wallet: pw_...'   # a real 1-cent toll
```

Amounts are **EUR cents** (500–20000); the rail is EUR-only, but cards in any currency
work — your issuer converts. A non-eur `currency` is an explicit 400; out-of-range
amounts are clamped and reported back as `adjusted_from`.

Your safety rails, not the merchant's: per-charge cap (default 100¢) and per-merchant
daily cap (default 1000¢) — `POST /v1/wallet/limits`. A merchant can never drain a wallet.
Balance and history: `GET /v1/wallet`.

## I built an API — get paid per call

```sh
# 1. Register once (save the key — shown once)
curl -s -X POST https://peage.intrane.fr/v1/merchants \
  -d '{"email":"you@example.com","name":"my api"}'

# 2. Per request: ask callers for an X-Peage-Wallet header, then charge it
curl -s -X POST https://peage.intrane.fr/v1/charge \
  -H 'Authorization: Bearer pm_...' \
  -d '{"wallet_token":"pw_...","amount_cents":2,"memo":"GET /search","idempotency_key":"req-123"}'
# 200 -> {charge_id, receipt, wallet_balance_cents}
# 402 -> insufficient funds, body tells the caller exactly how to top up (relay it verbatim)
```

No Stripe account, no pricing page, no customer database. 10% platform fee; payouts to
merchants monthly. Live merchants: [grepapi](https://grepapi.intrane.fr) (pay-per-lead
overage past the free cap) and [hart](https://github.com/javimosch/machin-hart)
(pay-per-publish overage past the free rate limit) — one header each.

**OSS authors:** ship the hook *inside* your tool so every self-hoster can monetize with
two env vars — the pattern is [`skills/peage-embed`](skills/peage-embed/SKILL.md);
reference embed: [open-serpapi](https://github.com/javimosch/machin-open-serpapi)'s
`METERED=1` build.

## A rail you can audit

Every cent is publicly accounted for — the live ledger invariant, no auth:

```sh
curl -s https://peage.intrane.fr/v1/solvency
# {"solvent":true,"funded_cents":{...},"allocated_cents":{...}}  — recomputed per request
```

The ledger is snapshotted off-site (WAL-safe) with restore drills. Boring on purpose.

## Receipts anyone can verify

Every charge returns an HMAC-signed receipt. Auditors, upstreams, or the paying human
can check it without trusting anyone:

```sh
curl -s 'https://peage.intrane.fr/v1/receipts?r=c_....<hmac>'
```

## The 402 convention

When a caller sends no wallet, reply `HTTP 402` with a machine-readable body:

```json
{"pay":{"rail":"peage","url":"https://peage.intrane.fr","price_cents":2,"header":"X-Peage-Wallet"}}
```

Agents that speak peage read it, fund themselves, and retry. That's the whole protocol.

## x402 — same thesis, fiat rails

[x402](https://www.x402.org) is right about everything except the wallet: HTTP 402 is
the payment layer the agent web needs. Where the x402 ecosystem settles that flow
on-chain, **peage is the same 402 primitive on prepaid fiat** — real EUR in a real
Stripe account, no chain, no volatility, no crypto wallet for your operator to hold.

- Today: peage-native 402 bodies (`{pay:{rail:"peage",url,price_cents,header}}`) that
  any agent can act on.
- On the roadmap: **wire-compatibility with the x402 header/body format**, so
  x402-aware agents can pay peage merchants without knowing the difference — peage as
  the fiat facilitator of the 402 web.

If you're building in the x402 ecosystem and want the fiat leg: javi@intrane.fr.

## Why not just Stripe?

Per-call card payments are impossible (fixed fees eat any sub-dollar charge), and
subscriptions were designed for humans with dashboards. peage keeps money
boring — one card top-up, then machine-native metering in cents.

---

Built with [machin (MFL)](https://github.com/javimosch/machin) — the whole rail is one
~110 KB static binary. An [intrane.fr](https://intrane.fr) product. Contact: javi@intrane.fr

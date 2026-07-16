---
name: peage-embed
description: Embed an optional peage merchant hook into an OSS tool or self-hostable service so ANY self-hoster can charge callers per invocation with two env vars and zero payments code. Use when adding monetization support to an open-source CLI, server, or library — as the author shipping the hook, or as a self-hoster enabling it.
---

# peage: the embed pattern

Goal: your OSS tool ships with monetization **support**, off by default. A self-hoster
flips two env vars and starts charging agents per call through the hosted rail
(`https://peage.intrane.fr`) — no Stripe account, no payments code, no dashboard.

Reference implementation: [`machin-open-serpapi/src/meter.src`](https://github.com/javimosch/machin-open-serpapi/blob/master/src/meter.src) (~55 lines).

## The rules (all five, non-negotiable)

1. **Off by default, honestly.** If your tool advertises being network-free or
   dependency-light, make the hook a *build-time* opt-in (compile a no-op stub by
   default, the real hook behind `METERED=1`) so the default artifact keeps its
   promises. Otherwise a runtime `PEAGE_MERCHANT_KEY`-unset = no-op is enough.
2. **Charge before serve.** An agent that already got the result has no reason to pay.
3. **Pass peage errors through verbatim.** The 402 body tells the caller exactly how to
   fund itself (`{merchant_id, min_cents, how}`) — never rewrite it into a vague error.
4. **Keep output channels pure.** Receipts and charge events go to stderr (CLI) or a
   response field (server); never pollute the tool's primary output.
5. **Always send an idempotency key** when the caller supplies a request id — retries
   must never double-bill.

## Env contract (keep these names — agents learn them once)

| var | meaning |
|---|---|
| `PEAGE_MERCHANT_KEY` | the self-hoster's `pm_…` key; unset = tool is free |
| `PEAGE_PRICE_CENTS`  | price per invocation (pick a sane default, e.g. 1) |
| `PEAGE_URL`          | rail override (default `https://peage.intrane.fr`) |
| `PEAGE_FAIL_OPEN`    | `1` = serve free when the rail is unreachable; default refuse |

The **caller's** wallet arrives per request: `X-Peage-Wallet` header (servers) or
`PEAGE_WALLET_TOKEN` env (CLI wrappers).

## The hook (pseudocode, any language)

```
def meter_charge(memo, idem):
    key = env("PEAGE_MERCHANT_KEY");  if !key: return OK          # free instance
    wallet = caller_wallet();         if !wallet: return PAY_REQUIRED(price)
    status, body = POST env("PEAGE_URL")+"/v1/charge",
        auth="Bearer "+key,
        json={wallet_token: wallet, amount_cents: price, memo: memo, idempotency_key: idem}
    if unreachable: return env("PEAGE_FAIL_OPEN")=="1" ? OK_WITH_WARNING : REFUSE
    if status==200: emit_receipt(body.receipt); return OK
    return RELAY(status, body)                                    # 402/403/404 verbatim
```

`PAY_REQUIRED` is the discovery response for wallet-less callers:

```json
{"error":"payment_required","pay":{"rail":"peage","url":"https://peage.intrane.fr","price_cents":1,"header":"X-Peage-Wallet"}}
```

## For self-hosters enabling it

1. Register once: `curl -s -X POST https://peage.intrane.fr/v1/merchants -d '{"email":"payout@you.com","name":"my instance"}'` → save the `pm_…` key.
2. Set `PEAGE_MERCHANT_KEY` + `PEAGE_PRICE_CENTS` (and rebuild with `METERED=1` if the tool uses the build-time variant).
3. Watch earnings: `GET /v1/merchant` with your key. Payouts: monthly (see the rail's `/llms.txt`).

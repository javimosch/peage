# peage — vision

## North star

**Every API call an agent makes can carry payment, and peage is the rail it rides.**

The internet's monetization primitives — subscriptions, seats, API-key dashboards,
checkout pages — were designed for humans with browsers. Agents don't subscribe; they
*spend*: cents at a time, machine-negotiated, across many services, under caps their
operator set once. peage exists to make that spending as boring and trustworthy as an
HTTP request:

- a **wallet** any agent can mint in one call and any human can fund with a card,
- a **charge** any API can collect in one call, with a receipt anyone can verify,
- a **402** convention that lets an unfunded agent discover, price, and fix its own access.

Success looks like: *the default answer to "how do I charge agents for my API?" is a
two-env-var peage embed* — the way "how do I take cards?" became "use Stripe."

## The flywheel

1. Every metered API (merchant) makes every existing wallet more valuable.
2. Every funded wallet makes metering more attractive to the next API builder.
3. OSS tools that **embed** the merchant hook (see `skills/peage-merchant`) turn every
   self-hosted deployment into a new merchant — distribution we don't run or pay for.

peage takes a platform fee (10%) on every charge. Revenue scales with ecosystem
transaction volume, not with our own traffic.

## Principles

- **Agent-first, humans as funding interface.** The docs are `/llms.txt`; the UI is curl.
  A human appears exactly once in the loop: paying the top-up link their agent hands them.
- **Fiat, boring, honest.** Real EUR in a real Stripe account. No crypto, no float games.
  A machine-sent field we can't honour is an explicit error, never silently ignored;
  every adjustment (clamps, minimums) is reported back in the response.
- **The wallet holder is in control.** Per-charge caps and per-merchant daily caps are
  wallet-side; a merchant can never drain a wallet. Tokens are stored hashed, shown once.
- **Metering must be additive.** A merchant integration that can't reach peage falls back
  to its free tier — peage may add revenue, never a new failure mode (see the grepapi
  reference integration).
- **Small codebase, big win.** One ~110 KB machin binary, SQLite ledger, files < 500 LOC.

## Scaling steps (in order, each gated by real volume)

1. **Now — single-operator marketplace.** Manual month-end payouts (`peage payouts`),
   merchants onboarded by hand, one EUR ledger. Fine while every merchant is known to us.
2. **⚠️ Stripe Connect — the payout/KYC step (do not forget).** The moment a *stranger's*
   merchant balance first exceeds ~€50, move payouts to **Stripe Connect Express**:
   merchants onboard through Stripe-hosted flows (Stripe carries KYC/AML, identity, tax
   forms), payouts become automated transfers, and peage stops being the counterparty
   holding third-party money informally. This also unlocks marketplace terms-of-service
   and per-merchant payout schedules. Trigger: first external merchant balance > €50 or > 3
   external merchants — whichever comes first.
3. **Multi-currency** — only after Connect: per-currency ledgers or FX-at-topup; USD first.
4. **x402 wire-compatibility (a MUST, and a GTM move)** — speak the x402 header/body
   format as its fiat facilitator: every x402-aware agent becomes a potential peage
   wallet holder, and every peage merchant becomes reachable from the x402 web without
   custom integration. Spike DONE (2026-07-17): the spec is LF-governed and explicitly
   rail-agnostic, Cloudflare ships a production fiat binding, and peage maps cleanly
   (exact<->charge, upto<->holds, receipt<->transaction) — compatibility is now a
   ~1-week job. Implement when the canonical fiat-credit binding (x402 PR #2612)
   merges, or on first inbound x402-ecosystem interest.

## Non-goals

- No human dashboards, ever (agent-first positioning is set in stone).
- No crypto rails.
- No credit/postpaid balances — prepaid only; the ledger never goes negative.

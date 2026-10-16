# Threat Model — Summary

Library (`noizu_clickup` v0.1.0, Elixir client for ClickUp API v2). No server,
no store, no listeners. Crown jewels: the consumer's ClickUp token, the
webhook signature gate, the dependency tree compiled into consumers.

## Trust Boundaries

1. Consumer app ↔ library (consumer config trusted)
2. Library ↔ api.clickup.com (HTTPS egress; responses untrusted data)
3. ClickUp → consumer webhook endpoint (verified via shared HMAC secret)
4. hex.pm → build (supply chain)

## Register (9 items · 2026-10-17)

| ID | Sev | Finding | Status |
|---|---|---|---|
| T-001 | High | No redacting `Inspect` on `%Client{}` — logging the struct prints the raw token | Mitigated 2026-10-17 (token masked in `inspect/2`; `RedactionTest`) |
| T-002 | Medium | OAuth `client_secret` in GET query params (ClickUp-documented form) | Accepted |
| T-003 | Medium | Webhook signature is body-only — no timestamp/nonce → replays verify true | Open (scheme-inherent; raw-body + dedupe guidance in moduledoc/README) |
| T-004 | Medium | Hex supply chain (req/jason + transitive) runs in consumers | Mitigated (pin+checksum+minimal deps) |
| T-005 | Low | Resource ids interpolated unescaped into URL paths | Mitigated 2026-10-17 (`Request.segment/1` encodes every id; `PathEncodingTest`) |
| T-006 | Low | `base_url` override can exfiltrate the token | Accepted |
| T-007 | Low | 429 retry blocks caller ≤ ~30 s worst case | Mitigated (bounded; waits clamped, sleep injectable) |
| T-008 | Low | Non-map error bodies inspected (500 chars) into error text | Mitigated |
| T-009 | Low | Token readable from app env by any node code | Accepted |

6 mitigated · 1 open · 2 accepted.

## Positive Controls

Constant-time `:crypto.hash_equals` compare with length guard · redacting
`Inspect` on `%Client{}` (token never in logs/crash reports) · raw-body
verification fails closed on re-serialized bodies · no token ever in error
paths; Req redacts `authorization` in request inspect output · single bounded
429-only retry layer with clamped waits (Req retry disabled) · every resource
id URI-encoded into its path segment · fail-fast on missing token · hermetic
`Req.Test` test suite.

## Detail Documents

[token-handling](threats/token-handling.md) ·
[webhook-signature](threats/webhook-signature.md) ·
[retry-behavior](threats/retry-behavior.md) ·
[supply-chain](threats/supply-chain.md) ·
[attack-surface](threats/attack-surface.md)

# Threats: Attack Surface Enumeration

Method: every ingress, egress, store, and boundary crossing of the library
(grounded in [PROJ-ARCH.md](../PROJ-ARCH.md), verified against code 2026-10-17),
with STRIDE applied per crossing.

## Ingresses (data entering the consumer's trust domain)

| Surface | Vector | Trust treatment |
|---|---|---|
| API responses | Decoded JSON from `api.clickup.com` returned as-is (`{:ok, map}`) | Untrusted data; never executed, never used in control flow. Risk is data-quality, not code execution. |
| Error bodies | Non-2xx bodies shaped into `%Error{message}` (map fields `err`/`ECODE`/`message`; else 500-char `inspect`) | Flows into consumer logs via raised exceptions / `{:error, _}` — T-008 |
| Webhook deliveries | ClickUp → consumer's HTTP endpoint, `X-Signature` header | Consumer-owned ingress; the library's `verify_signature/3` is the trust gate — see [webhook-signature.md](webhook-signature.md) |
| OAuth redirect | Browser redirect to consumer's `redirect_uri` with `code` + `state` params | Consumer validates `state` (CSRF) and the code is exchanged server-side; the library builds the URL and performs the exchange only |

## Egresses (credentials/data leaving the consumer's trust domain)

| Surface | What leaves | Risk |
|---|---|---|
| `Request.request/4` → `api.clickup.com` | Token in the `authorization` header; payloads in JSON bodies | TLS-protected; token exposed only on TLS strip/MITM (platform concern) or base_url override (T-006) |
| `OAuth.exchange_code/4` → `/oauth/token` | `client_id`, **`client_secret`**, `code` as **GET query params** | Query strings leak via intermediary/access logs — T-002 |
| Consumer `req_options` | Arbitrary Req options merged into every request (incl. custom adapters, logging steps) | Consumer-introduced egress; library cannot sandbox it |

## Stores

| Where | Secret | Exposure |
|---|---|---|
| `%Noizu.ClickUp.Client{}` in consumer memory | `token` plaintext | `inspect`able (T-001); BEAM process memory; crash dumps |
| `:noizu_clickup, :client` app env | optional `token` default | Readable by any code on the node (T-009) |
| Webhook `secret` (from `create/3` response) | shared HMAC key | Held by consumer; compromise → attacker can forge valid signatures. Library never persists it. |
| `mix.lock` | no secrets | pins the supply chain (T-004) |

## Boundary crossings × STRIDE (summary)

| Crossing | S | T | R | I | D | E |
|---|---|---|---|---|---|---|
| Consumer config → library | token sourcing | base_url (T-006) | — | token in struct (T-001) | blocking sleep (T-007) | req_options code |
| Library → ClickUp API | — | path ids URI-encoded per segment (T-005 mitigated) | request receipts on ClickUp side | secret in OAuth query (T-002) | retry amplification vs rate budget | — |
| ClickUp → webhook endpoint | forged deliveries (blocked by HMAC, T-003 residual: replay) | body tampering (fails closed) | no delivery log in library | secret needed to verify | — | — |
| hex.pm → build | typosquat/compromise (T-004) | lockfile tampering | — | — | dep availability | malicious dep code runs in consumer |

No elevation-of-privilege crossing exists: the library runs inside the
consumer's own process privileges and grants nothing beyond them.

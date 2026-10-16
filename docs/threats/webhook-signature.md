# Threats: Webhook Signature Verification

Scope: `Webhook.verify_signature/3` (`webhook.ex`) — the trust gate for
ClickUp → consumer deliveries. ClickUp's scheme (contract § 3.11): at create
time the webhook gets a `secret`; each delivery carries `X-Signature` =
lowercase hex HMAC-SHA256 of the **raw request body**, keyed with that secret.

## The implementation (verified 2026-10-17)

```elixir
expected = Base.encode16(:crypto.mac(:hmac, :sha256, secret, raw_body), case: :lower)

case signature do
  sig when is_binary(sig) ->
    given = String.downcase(sig)
    byte_size(given) == byte_size(expected) and
      :crypto.hash_equals(expected, given) == true
  _ -> false
end
```

## Controls and their limits

| Control | Status | Detail |
|---|---|---|
| **Constant-time compare** | Mitigated | `:crypto.hash_equals/2` (OTP ≥ 25, guaranteed by `elixir ~> 1.15`) compares digests without early exit; the preceding `byte_size/2` guard only leaks length (always 64 here) and prevents the raise `hash_equals/2` performs on unequal sizes. No data-dependent timing on secret or body. |
| **Raw-body requirement** | Mitigated (fail-closed) | The HMAC is over the **exact delivered bytes**. A consumer that re-serializes parsed JSON (key order/whitespace differences) gets `false` — i.e. misuse fails **closed**, never open. The consumer must capture the raw body before `Plug.Parsers` (custom body reader or `cache_raw_body`-style pattern). |
| **Length / garbage input** | Mitigated | Wrong-length header, non-binary, and `nil` all return `false` (test-covered: `webhook_test.exs` covers valid lower/upper hex, wrong secret, tampered body, wrong length, missing). |
| **Hex case** | Mitigated | Header is downcased before compare, so upper- and lowercase hex both verify (ClickUp sends lowercase; tolerance tested). |
| **Body-only signature → replay** | **Open — T-003** | See below. |
| **Secret compromise** | Consumer-held | The secret exists only in the create response and consumer storage; the library never persists it. Anyone with the secret can forge deliveries — store it like a credential. |

## T-003 (Medium) — replay: the signature has no time dimension

**Finding.** The MAC covers the body only. There is no timestamp, nonce, or
delivery-id material in the signed payload, and ClickUp sends no separate
signed timestamp header. Therefore a captured (or maliciously re-sent) delivery
verifies `true` forever: an attacker who can observe a delivery once — or who
can reach the consumer endpoint without observing it, e.g. by replaying a
publicly-triggerable event — gets each benign delivery accepted arbitrarily
many times, and cannot be *distinguished* from ClickUp by signature alone.

**Impact.** Duplicated side effects in the consumer (double task processing,
double notifications), and un-attributable deliveries. It does **not** let an
attacker *forge new* event content — bodies still need the secret.

**Status: Open** (inherent to ClickUp's scheme — cannot be fixed unilaterally;
would need ClickUp to sign a timestamp). The library ships **no new crypto**
against this; instead the effective consumer mitigations are now documented
where consumers will see them — the `Noizu.ClickUp.Webhook` moduledoc and the
README ("Webhook verification") both instruct: verify against the **raw body**
and **dedupe on `webhook_id` + `event` + `history_items[].id`**.

**Consumer mitigations (effective today):**

1. Dedup on whatever delivery-identifying fields ClickUp's payload carries
   (webhook id, event, and the affected entity/history ids — payload schemas
   are the consumer's concern per contract § 6); persist processed ids and
   drop repeats. This is the standard mitigation.
2. Treat handlers as idempotent (upsert semantics) so replays are no-ops.
3. TLS + sender allowlisting where feasible (ClickUp publishes no fixed source
   ranges — do not rely on IP allowlisting).

## Non-goals / out of scope

- **Payload parsing** — the contract (§ 6) explicitly leaves payload schemas
  and parsing to consumers; `verify_signature/3` is byte-level only.
- **Delivery ordering / authenticity of *sequence*** — the scheme proves the
  body came from ClickUp, not when or in what order; dedup storage is the only
  ordering defense.
- **Endpoint hardening (HTTPS, auth on the receiving route, body size caps)** —
  consumer-owned; recommended but not enforceable by this library.

# Threats: Retry Behavior

Scope: the 429 retry loop in `Request` (`request.ex`); Req's built-in retry is
disabled (`retry: false` on every request the library builds), so this loop is
the **only** code path that ever re-sends a request.

## Policy (verified)

- **Retried:** HTTP 429 only. Never 5xx, never timeouts, never connection
  errors, never OAuth errors.
- **Attempts:** at most `client.max_retries` (default 2) retries → worst case 3
  sends total.
- **Wait:** until `X-RateLimit-Reset` (Unix seconds) — `reset*1000 − now`,
  floored at 0, **clamped to `client.retry_cap_ms`** (default 15 000 ms).
  Missing or unparseable header → fixed 1 000 ms.
- **Semantics:** the identical request (same method/path/body) is re-sent after
  a synchronous `Process.sleep/1` in the caller's process.

## Security-relevant properties

| Property | Assessment |
|---|---|
| **Mutation duplication** | Low. 429 means the request was **not processed** (rate budget exhausted before handling), so a retry is not a duplicate write — unlike 5xx/timeout retries, where the first attempt may have landed. The 429-only rule is what makes retrying mutations safe; the contract (§ 5) documents this as deliberate. |
| **Amplification against ClickUp** | Bounded. ≤ 2 extra sends per call, sleeps honor the reset header, so a retrying client cannot meaningfully worsen its own rate-limit standing beyond one extra round per window. |
| **Caller-side DoS (T-007, Low)** | The retry blocks the calling process up to `retry_cap_ms` per attempt — worst case ≈ 30 s (2 × 15 s) plus request time. Calling from a LiveView, GenServer handle_call, or request process stalls it. Mitigated by the bounds; **consumer guidance:** call from a `Task`/`Req`-friendly context, or set `max_retries: 0` and handle 429 explicitly when latency matters. |
| **Timing side effects** | The clamp means the client never sleeps unboundedly on a bogus/future `X-RateLimit-Reset` from a compromised API response (untrusted data): worst case is the configured cap, not attacker-chosen hours. A negative computed wait floors to 0. |
| **No jitter / thundering herd** | All clients of a token wake at the same reset instant; ClickUp-side, this shapes consumer traffic, not a vulnerability of the library. Noted for completeness. |

## What is deliberately NOT retried

- **5xx / network errors** — could have been processed server-side; retrying
  mutations on them risks duplicates, and the contract leaves that decision to
  the consumer.
- **`OAUTH_*` errors** — revoked/invalid tokens fail fast; hammering with a
  dead token only burns the caller's process time.
- **Anything inside streams** — stream paging raises on first failure rather
  than retrying; a retry inside `Stream.resource/3` would multiply silent
  re-reads. Consumers who want retries compose them outside the stream.

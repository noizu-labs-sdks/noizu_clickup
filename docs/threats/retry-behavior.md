# Threats: Retry Behavior

Scope: the 429 retry loop in `Request` (`request.ex`); Req's built-in retry is
disabled (`retry: false` on every request the library builds), so this loop is
the **only** code path that ever re-sends a request.

## Policy (verified 2026-10-17, post-hardening)

- **Retried:** HTTP 429 only. Never 5xx, never timeouts, never connection
  errors, never OAuth errors.
- **Attempts:** at most `client.max_retries` (default 2) retries → worst case 3
  sends total.
- **Wait:** resolved from the response headers in order —
  1. `X-RateLimit-Reset`: values ≥ `1_000_000_000` are Unix epoch seconds
     (wait = `reset*1000 − now`); smaller values are treated as
     *seconds-until-reset* so a delta-style proxy value (`"90"`) is not read as
     an epoch in the past (which would floor the wait to 0 and hammer the API
     with immediate retries);
  2. `Retry-After`: seconds (HTTP-date form is unparseable → falls through);
  3. neither parseable (or missing) → fixed 1 000 ms.
  Every computed wait is **clamped to `0..retry_cap_ms`** (default 15 000 ms):
  negative/past values floor to 0, garbage/far-future values cap out — an
  untrusted header can never make the client sleep unboundedly or retry with
  zero delay.
- **Semantics:** the identical request (same method/path/body) is re-sent after
  a sleep in the caller's process. The sleep function is the client's
  `retry_sleep` (default `&Process.sleep/1`), injectable for tests.
- **Test coverage:** `Noizu.ClickUp.ErrorRateLimitTest` — clamping table
  (past/negative/garbage/far-future reset, delta-style values, `Retry-After`
  fallback, precedence, Req map-shaped headers) plus an end-to-end injected
  sleep asserting the retry observes the clamped wait.

### Fixed alongside (worth recording)

The pre-hardening header lookup only understood Req's *old* list-of-tuples
header shape; Req 0.7 responses carry headers as a **map**, so the live path
silently never matched `X-RateLimit-Reset` and always slept the fixed 1 000 ms
(the epoch math only ran in tests that passed list-shaped headers). The lookup
now accepts both shapes — the header is actually honored in production again.

## Security-relevant properties

| Property | Assessment |
|---|---|
| **Mutation duplication** | Low. 429 means the request was **not processed** (rate budget exhausted before handling), so a retry is not a duplicate write — unlike 5xx/timeout retries, where the first attempt may have landed. The 429-only rule is what makes retrying mutations safe; the contract (§ 5) documents this as deliberate. |
| **Amplification against ClickUp** | Bounded. ≤ 2 extra sends per call, sleeps honor the reset header, so a retrying client cannot meaningfully worsen its own rate-limit standing beyond one extra round per window. |
| **Caller-side DoS (T-007, Low)** | The retry blocks the calling process up to `retry_cap_ms` per attempt — worst case ≈ 30 s (2 × 15 s) plus request time. Calling from a LiveView, GenServer handle_call, or request process stalls it. Mitigated by the bounds; **consumer guidance:** call from a `Task`/`Req`-friendly context, or set `max_retries: 0` and handle 429 explicitly when latency matters. |
| **Timing side effects** | The clamp means the client never sleeps unboundedly on a bogus/future `X-RateLimit-Reset` from a compromised API response (untrusted data): worst case is the configured cap, not attacker-chosen hours. Negative/past computed waits floor to 0, and delta-style reset values are honored instead of being misread as long-past epochs. |
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

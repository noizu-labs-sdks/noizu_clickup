# Architecture: Errors and Retry

## The single error type

`Noizu.ClickUp.Error` (`error.ex`) is a `defexception` used for **every**
failure — API and transport alike:

| Field | API failure | Transport failure |
|---|---|---|
| `status` | HTTP status integer | `nil` |
| `code` | ClickUp `ECODE` string when the body carries one (`"OAUTH_019"`, …), else `nil` | `nil` |
| `message` | `err` → `message` → 500-char-truncated `inspect` of the body | the exception's `message/1`, else `inspect` |

Being an exception struct means streams can `raise` it directly and consumers
can `raise err` in their own catch-alls; `message/1` renders
`"ClickUp request failed (HTTP 401) [OAUTH_019]: Token invalid"`-style text.

The ClickUp error body shape is pinned in [`API-CONTRACT.md`](../API-CONTRACT.md)
§ 5 (`{"err": "Token invalid", "ECODE": "OAUTH_019", "message": "..."}`); the
ECODE catalog (revoked token, unauthorized workspace, duplicate webhook, …)
lives there, not in code — the client just surfaces the string.

## Retry policy

<!-- 〚🔀:46ef6388-cd8c-5aa3-92a1-ddcc065e88cb〛 noizu_clickup:retry_policy :: Single 429-only retry layer — bounded attempts, reset-based wait clamped to retry_cap_ms. -->

Exactly one retry layer exists: the 429 loop in `Request` (`request.ex`).
Req's built-in retry is disabled (`retry: false` on every request) so no
second, invisible retry can fire.

- **What is retried:** HTTP 429 only. Never 5xx, never timeouts, never
  connection errors — mutations are therefore never duplicated by network-level
  retries (ClickUp reads are naturally idempotent; the contract notes the 429-only
  choice is what keeps mutations safe in practice).
- **How many:** at most `client.max_retries` (default 2) retries, then the 429
  is returned as `{:error, %Error{status: 429}}`.
- **How long between attempts:** sleep until `X-RateLimit-Reset` (Unix
  seconds) — `reset*1000 − now`, floored at 0, clamped to `client.retry_cap_ms`
  (default 15 000 ms). Missing/unparseable header → fixed 1 000 ms.
  A sleeping caller blocks its own process; there is no backoff ladder or
  jitter beyond the reset-based wait.

Rate-limit budgets themselves are per token, per minute, by workspace plan —
100 / 1 000 / 10 000 req/min (see contract § 5).

<!-- 〚/🔀:46ef6388-cd8c-5aa3-92a1-ddcc065e88cb〛 -->

## Streams vs tuples

Pagination streams (`Task.stream_team_tasks/3`, `Comment.stream_task_comments/2`)
raise `%Noizu.ClickUp.Error{}` on request failure — an enumerable cannot return
`{:error, _}` per element. Partial results already yielded remain consumed; the
raise surfaces on the `Enum` driving the stream. Tuple semantics require the
paginated (`list`/`get_*`) functions.

## Fail-fast configuration errors

- `Client.authorization_headers/1` with `token: nil` raises `ArgumentError`
  before any HTTP happens — a misconfigured client can never silently issue an
  unauthenticated request.
- `Client.new/1` merges app-env defaults (`:noizu_clickup, :client`) with the
  given opts and `struct!/2`s the result, so unknown option keys raise at
  construction time.

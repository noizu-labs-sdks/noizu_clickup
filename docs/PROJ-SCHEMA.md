# Project Schema

`noizu_clickup` is a stateless client library: **no persistence layer exists** —
no database, no Ecto/Liquibase changelogs, no KV/Redis, no on-disk data files.
The only runtime state the library holds is the caller-owned
`%Noizu.ClickUp.Client{}` struct, plus optional `:noizu_clickup, :client`
application-env defaults. There is therefore no ERD in this document; per the
schema-scope rules, the sections below cover the structured data the repo
actually contains.

What "data" means here is **wire data**: string-keyed JSON maps exchanged with
the ClickUp API v2. [`API-CONTRACT.md`](API-CONTRACT.md) is the source of truth
for every request/response shape; this document inventories the shapes the
library itself owns and points at the contract for the rest.

## Data Inventory

| Kind | Where it lives | Shape | Source of truth |
|---|---|---|---|
| API request bodies | `Request.request/4` `:json` opt | map; top-level keys may be atom or string (stringified before send); nested values sent unchanged | [API-CONTRACT.md](API-CONTRACT.md) per-endpoint tables |
| API response envelopes | every resource-module return | decoded JSON — string-keyed maps, unmodified (empty body → `%{}`) | [API-CONTRACT.md](API-CONTRACT.md) |
| ClickUp error body | `Error.from_response/2` | `{"err": "...", "ECODE": "...", "message": "..."}` | [API-CONTRACT.md](API-CONTRACT.md) § 5 |
| Client config | `%Noizu.ClickUp.Client{}` | struct — fields below | `lib/noizu/clickup/client.ex` |
| App-env defaults | `:noizu_clickup, :client` | keyword list of Client options | `client.ex` (`new/1`) |
| Webhook delivery | consumer's HTTP endpoint | ClickUp JSON envelope + `X-Signature` header (hex HMAC-SHA256 of the **raw** body) | `lib/noizu/clickup/webhook.ex`, [threats/webhook-signature.md](threats/webhook-signature.md) |
| OAuth token exchange | `OAuth.exchange_code/4` | query params `client_id`/`client_secret`/`code` → JSON token body | `lib/noizu/clickup/oauth.ex` |

## Structured Data Details

### `%Noizu.ClickUp.Client{}` — config struct

| Field | Type | Default | Description |
|---|---|---|---|
| `token` | `String.t \| nil` | `nil` | Personal `pk_…` or OAuth access token; required for API calls (raises `ArgumentError` if missing when headers are built) |
| `auth_style` | `:personal \| :bearer` | `:personal` | Raw `authorization: <token>` vs `authorization: Bearer <token>` |
| `base_url` | `String.t` | `https://api.clickup.com/api/v2` | Target host/path; override sends the token elsewhere (T-006) |
| `req_options` | `keyword()` | `[]` | Merged last into every `Req.new/1` — test plugs, transport tuning |
| `max_retries` | `non_neg_integer()` | `2` | 429 retry budget |
| `retry_cap_ms` | `pos_integer()` | `15_000` | Upper clamp on the 429 sleep |
| `retry_sleep` | `(pos_integer() -> any)` | `&Process.sleep/1` | Injectable so tests observe waits without sleeping |

`inspect/2` of the struct redacts `token` to a ≤4-char prefix + `[REDACTED]`
(T-001) — [threats/token-handling.md](threats/token-handling.md).

### `%Noizu.ClickUp.Error{}` — the single error struct

| Field | API failure | Transport failure |
|---|---|---|
| `status` | HTTP status integer | `nil` |
| `code` | ClickUp `ECODE` string, or `nil` | `nil` |
| `message` | `err` → `message` → 500-char-truncated `inspect` of the body | exception `message/1`, else `inspect` |

Details and rationale: [arch/error-retry.md](arch/error-retry.md).

### Application env

```elixir
# optional defaults for Client.new/0 — the only config key the library reads
config :noizu_clickup, :client, [token: "...", auth_style: :personal]
```

One key (`:client`), a keyword list wrapped via `List.wrap/1` and merged under
per-call opts (`new/1` opts win, `struct!/2` raises on unknown keys). Anything
stored here is readable by any code on the BEAM node — T-009, accepted;
[THREAT-MODEL.md](THREAT-MODEL.md).

### Wire envelope conventions

- **Responses pass through unmodified** — string-keyed maps, no normalization
  or DSL layer (deliberate; see PROJ-ARCH Key Decisions).
- **Query encoding** — list values become repeated `key[]=value` pairs; values
  are `URI.encode_www_form/1`-encoded; path ids are percent-encoded per segment
  (`Request.segment/1`, T-005).
- **Pagination** — two models: `page`-based (`Task.get_team_tasks/3`, `last_page`)
  and cursor-based (`Comment.list_task_comments/3`, `start` + `start_id`).

## ERD

None — no relational store exists in this repository. Payload tables and the
error-body/ECODE catalog live in [`API-CONTRACT.md`](API-CONTRACT.md).

→ How these shapes flow through the request lifecycle:
[arch/data-flow.md](arch/data-flow.md). Components ↔ directories:
[PROJ-LAYOUT.md](PROJ-LAYOUT.md).

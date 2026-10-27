# Project Schema — Summary

**No persistence layer** — `noizu_clickup` is a stateless client library: no
database, no KV/Redis, no data files. Data here = wire data (string-keyed JSON
maps) plus the two in-repo structs. Source of truth for API payload shapes:
[API-CONTRACT.md](API-CONTRACT.md).

## Data Inventory

| Kind | Shape | Truth |
|---|---|---|
| Request bodies | map, top-level keys atom-or-string, sent as JSON | API-CONTRACT.md |
| Response envelopes | decoded JSON, string-keyed, unmodified (empty → `%{}`) | API-CONTRACT.md |
| ClickUp error body | `{"err", "ECODE", "message"}` | API-CONTRACT.md § 5 |
| `%Client{}` | config struct (7 fields below) | client.ex |
| App env | single key `:noizu_clickup, :client` — keyword list of Client defaults | client.ex `new/1` |
| Webhook delivery | ClickUp envelope + `X-Signature` (hex HMAC-SHA256 of raw body) | webhook.ex |
| OAuth exchange | `client_id`/`client_secret`/`code` query params → token JSON | oauth.ex |

## `%Client{}` fields

`token` (nil) · `auth_style` (:personal) · `base_url`
(https://api.clickup.com/api/v2) · `req_options` ([]) · `max_retries` (2) ·
`retry_cap_ms` (15_000) · `retry_sleep` (&Process.sleep/1).
`inspect/2` redacts `token` (T-001).

## `%Error{}` fields

`status` (HTTP int; nil on transport) · `code` (ECODE string; nil) · `message`.

## Conventions

Responses unmodified · `key[]=` repeated-list query encoding · path ids
percent-encoded per segment (T-005) · pagination: `page`/`last_page` (tasks)
and `start`+`start_id` cursor (comments) · **no ERD — nothing relational
exists**.

Detail: [PROJ-SCHEMA.md](PROJ-SCHEMA.md) · flow: [arch/data-flow.md](arch/data-flow.md)

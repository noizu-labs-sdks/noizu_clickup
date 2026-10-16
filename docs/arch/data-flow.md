# Architecture: Request Data Flow

How a call travels from consumer code to the ClickUp API and back. All paths
below are relative to `lib/noizu/clickup/`.

<!-- 〚🔀:6eb78b5e-6b1e-5f4c-9645-4b08c0217004〛 noizu_clickup:request_flow :: Request lifecycle — resource module → Request.request/4 → Req dispatch → 429 retry → result shaping. -->

## 1. Call entry — resource module

Every public function has the shape
`(client, ...path_ids..., payload?, opts \\ [])` and immediately delegates:

```elixir
def create(client, list_id, attrs),
  do: Request.request(client, :post, "/list/#{list_id}/task", json: attrs)
```

The resource module knows the endpoint path and response envelope; nothing else
knows HTTP. Payload maps may use atom or string keys at the top level
(`Request.stringify_json/1` stringifies top-level keys); nested structures are
sent unchanged.

## 2. Transport — `Request.request/4`

`Request` (`request.ex`, `@moduledoc false`) is the single choke point:

1. **Query encoding** — `encode_params/1` flattens keyword/map params; list
   values become repeated `key[]=value` pairs (ClickUp's documented form, e.g.
   `statuses[]=to%20do`). Keys pass through raw (caller-controlled
   snake_case + the `[]` suffix); values are `URI.encode_www_form/1`-encoded.
   Encoded pairs are appended to the path as a query string.
2. **Req construction** — `Req.new` with `base_url`, `method`, `url`,
   `headers` (auth from `Client.authorization_headers/1`, plus
   `content-type: application/json` on bodyless requests), and `retry: false`
   — Req's built-in retry is disabled so the library's 429 retry is the only
   retry layer. `client.req_options` is merged **last**, which is how tests
   inject `plug: {Req.Test, ...}`.
3. **Dispatch** — synchronous `Req.request/1`; no process, pool, or queue of
   the library's own.

## 3. Response handling

| Outcome | Result |
|---|---|
| 2xx | `{:ok, decoded_body}` — string-keyed map, unmodified; empty body (204/`{}`) normalized to `%{}` |
| 429 | Handled by the retry loop (below) |
| other status | `{:error, Error.from_response(status, body)}` |
| transport exception | `{:error, Error.transport(exception)}` (no HTTP status) |

## 4. Rate-limit retry loop

On 429, `rate_limited/5` decides:

- `attempt < client.max_retries` (default 2) →
  `Process.sleep(retry_wait_ms/2)` then re-issue the identical request.
- otherwise → `{:error, %Error{status: 429}}`.

`retry_wait_ms/2` reads `X-RateLimit-Reset` (Unix seconds): sleep =
`reset*1000 − now`, floored at 0 and **clamped to `client.retry_cap_ms`**
(default 15 s). Missing or unparseable header → fixed 1 s. Only 429 is
retried — never 5xx or timeouts — so a mutation can at worst be re-sent
within the same rate-limit window, never duplicated by network-layer retries.

<!-- 〚/🔀:6eb78b5e-6b1e-5f4c-9645-4b08c0217004〛 -->

## 5. Pagination — two models, one stream pattern

| Surface | Model | End of data |
|---|---|---|
| Filtered team tasks (`Task.get_team_tasks/3`) | `page` integer from **0**, ≤ 100/page | `last_page == true` **or** empty `tasks` page |
| Task comments (`Comment.list_task_comments/3`) | cursor pair `start` (date ms of last comment) + `start_id` (its id), newest→oldest, 25/page default | empty `comments` page (no `last_page` exists) |
| Everything else | single full array | n/a |

Paginated functions return the raw envelope `{:ok, page_map}`. Stream variants
(`Task.stream_team_tasks/3`, `Comment.stream_task_comments/2`) wrap the paging
loop in `Stream.resource/3` and yield **individual items**. Because a `Stream`
cannot return `{:error, _}` per element, a request failure inside a stream
**raises** `%Noizu.ClickUp.Error{}` (an exception struct, so `raise` uses its
`message/1`); consumers wanting tuple semantics use the paginated functions.

## 6. Auth header construction — `Client.authorization_headers/1`

- `token: nil` → raises `ArgumentError` (fail fast; only token-less calls such
  as `OAuth.exchange_code/4` are meant to build with `new(token: nil)`).
- `auth_style: :personal` (default) → `authorization: <token>` (raw `pk_…`, no
  `Bearer`).
- `auth_style: :bearer` → `authorization: Bearer <token>` (OAuth access token).

## 7. OAuth side path

`OAuth.exchange_code/4` bypasses `Request` (it needs no client token): its own
`Req` call to `GET /oauth/token` with `client_id`, `client_secret`, `code` as
query params, `retry: false`, same error shaping. `authorize_url/1` is pure
string building for the browser redirect and performs no I/O.

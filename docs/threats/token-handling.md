# Threats: Token Handling and Leakage

Scope: the ClickUp token (personal `pk_…` or OAuth access token) and the OAuth
`client_secret`, from construction to wire. Code refs: `client.ex`, `oauth.ex`,
`request.ex`, `error.ex`.

## Token lifecycle in the library

1. **Construction** — `Client.new/1` (or app-env defaults via `new/0`) stores
   the token in plaintext in the struct. No in-memory obfuscation (none is
   meaningful on the BEAM).
2. **Use** — `Client.authorization_headers/1` emits exactly one header:
   `authorization: <token>` (`:personal`, default — raw token, no `Bearer`,
   per ClickUp's documented scheme) or `authorization: Bearer <token>`
   (`:bearer`). The token appears nowhere else in any request.
3. **Errors** — no error path includes the token: `Error.from_response/2` and
   `Error.transport/1` build `message` from the HTTP status, the response body,
   or the transport exception text. A token never appears in
   `{:error, %Error{}}` or in anything a stream raises.

## T-001 (High) — `%Client{}` has no redacting `Inspect`

**Finding.** The struct carries `token` as a plain binary with no
`defimpl Inspect`. Any of these prints the raw token into logs, telemetry, or
crash reports:

```elixir
Logger.debug("client: #{inspect(client)}")   # prints token: "pk_..."
```

Streams amplify this in a subtle way: a raised `%Error{}` renders via its own
`message/1` (safe), but an **uncaught** consumer crash whose process dictionary
or message queue holds the client can surface the struct in crash reports and
`erl_crash.dump`.

**Why it matters.** Personal tokens do not expire (ClickUp-documented); a
leaked token grants full workspace read/write until manually revoked.

**Status: Open** (owner: library maintainers). Fix is small and backward
compatible:

```elixir
defimpl Inspect, for: Noizu.ClickUp.Client do
  def inspect(client, opts) do
    %Noizu.ClickUp.Client{client | token: redact(client.token)}
    |> Inspect.Any.inspect(opts)   # mask token, keep the rest debuggable
  end
end
```

**Interim consumer guidance:** treat `%Client{}` like a password — never log
it, scope tokens per integration, rotate on suspicion. Note that inspecting a
`%Req.Request{}` *is* safe: Req 0.7.5 redacts the `authorization` header value
in its own Inspect implementation (verified in `deps/req/lib/req/request.ex`).

## T-002 (Medium) — `client_secret` in a GET query string

**Finding.** `OAuth.exchange_code/4` sends `client_id`, `client_secret`, and
`code` as **query params of a GET** — the form ClickUp documents for
`GET /oauth/token`. URLs (unlike headers/bodies) land in reverse-proxy access
logs, APM URL capture, and browser history, so any intermediary on that hop
sees the client secret.

**Status: Accepted** — the API offers no header/body form; the library
reproduces ClickUp's documented contract. Consumer guidance: perform the
exchange over direct HTTPS to `api.clickup.com`, avoid proxying it, and never
log the request URL. Register remains so a future ClickUp POST form gets
adopted deliberately.

## T-009 (Low) — token in application env

`:noizu_clickup, :client` is a documented optional default for `new/0`. App
env is world-readable on the node (`Application.get_env/2` from any process),
and it tends to be set from config files that get committed. Accepted with
guidance: prefer explicit `new(token: …)` from a secret manager over committing
config; keep the app-env path for single-tenant deployments.

## T-006 (Low) — `base_url` override as exfiltration channel

Both `Client` and `OAuth.exchange_code/4` accept a `base_url` override. Pointed
at an attacker-controlled host, it receives the token (or client secret) on
every call. This is a feature (`Req.Test` stubbing depends on it) and consumer
config is inside the trust boundary — accepted, but it means **config tampering
equals credential exfiltration**: protect the code path that builds clients.

## What the library is NOT exposed to

- Token-in-URL on API calls (header-only, verified in `request_headers/1`).
- Token persistence: nothing is written to disk, no cache, no telemetry.
- Token in query params on API calls: query strings carry only caller
  parameters (ids, filters) — verified in `encode_params/1` / `encode_query_pairs/1`.

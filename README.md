# Noizu.ClickUp

Elixir client for the [ClickUp API v2](https://developer.clickup.com) — workspaces, spaces,
folders, lists, tasks (incl. subtasks), comments, custom fields, members, tags, time tracking,
and signed webhooks. Built on [`Req`](https://hex.pm/packages/req), designed contract-first:
see [docs/API-CONTRACT.md](docs/API-CONTRACT.md) for the exact endpoint coverage, pagination
model, error shape, and rate-limit/retry behavior.

## Installation

```elixir
def deps do
  [
    {:noizu_clickup, "~> 0.1.0"}
  ]
end
```

## Quickstart

```elixir
# Personal API token (Authorization: pk_...) — the default auth style.
client = Noizu.ClickUp.Client.new(token: System.fetch_env!("CLICKUP_TOKEN"))

# OAuth token instead:
client = Noizu.ClickUp.Client.new(token: access_token, auth_style: :bearer)

{:ok, %{"user" => user}} = Noizu.ClickUp.User.get(client)
{:ok, %{"teams" => teams}} = Noizu.ClickUp.Workspace.list_authorized(client)
{:ok, %{"spaces" => spaces}} = Noizu.ClickUp.Space.list(client, team_id)

{:ok, %{"id" => task_id}} =
  Noizu.ClickUp.Task.create(client, list_id, %{"name" => "Ship it"})

# Pagination: one page at a time, or a lazy stream.
{:ok, %{"tasks" => tasks, "last_page" => last?}} =
  Noizu.ClickUp.Task.get_team_tasks(client, team_id, statuses: ["to do"], page: 0)

# Or stream every matching task across all pages:
all_tasks =
  Noizu.ClickUp.Task.stream_team_tasks(client, team_id, statuses: ["to do"])
  |> Enum.to_list()
```

## Error model

```elixir
case Noizu.ClickUp.Task.get(client, task_id) do
  {:ok, task} -> task
  {:error, %Noizu.ClickUp.Error{status: 429}} -> :rate_limited
  {:error, %Noizu.ClickUp.Error{status: status, code: "OAUTH_019"}} -> :revoked_token
  {:error, %Noizu.ClickUp.Error{} = err} -> raise err
end
```

429 responses are retried automatically (bounded, honoring `X-RateLimit-Reset`); every other
failure returns `{:error, %Noizu.ClickUp.Error{status, code, message}}`.

## Webhook verification

```elixir
# In your Plug/Phoenix webhook controller, against the RAW request body:
Noizu.ClickUp.Webhook.verify_signature(secret, raw_body, x_signature_header)
```

## License

MIT — see the `LICENSE` file in the repository.

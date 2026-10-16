defmodule Noizu.ClickUp do
  @moduledoc """
  Elixir client for the [ClickUp API v2](https://developer.clickup.com).

  Every call takes an explicit `Noizu.ClickUp.Client` config struct and returns
  `{:ok, map}` or `{:error, %Noizu.ClickUp.Error{}}`. Responses are the decoded
  JSON bodies as string-keyed maps, unmodified.

  ## Example

      client = Noizu.ClickUp.Client.new(token: System.fetch_env!("CLICKUP_TOKEN"))
      {:ok, %{"user" => user}} = Noizu.ClickUp.User.get(client)
      {:ok, %{"teams" => teams}} = Noizu.ClickUp.Workspace.list_authorized(client)

  ## Modules

    * `Noizu.ClickUp.Client` — configuration (token, auth style, base URL, Req options)
    * `Noizu.ClickUp.Error` — the error struct (`status`, `code`, `message`)
    * `Noizu.ClickUp.OAuth` — OAuth authorize URL + code exchange
    * `Noizu.ClickUp.User` — authorized user
    * `Noizu.ClickUp.Workspace` — authorized workspaces ("teams" in the API)
    * `Noizu.ClickUp.Space` — spaces
    * `Noizu.ClickUp.Folder` — folders
    * `Noizu.ClickUp.List` — lists
    * `Noizu.ClickUp.Task` — tasks, filtered team tasks, streams
    * `Noizu.ClickUp.Comment` — task comments, stream
    * `Noizu.ClickUp.CustomField` — accessible fields, set/clear values
    * `Noizu.ClickUp.Member` — task/list members
    * `Noizu.ClickUp.Tag` — space tags, task tags
    * `Noizu.ClickUp.TimeEntry` — time tracking entries, timers
    * `Noizu.ClickUp.Webhook` — webhook CRUD + signature verification

  Payload maps may use atom or string keys at the top level; nested structures
  are sent unchanged. See `docs/API-CONTRACT.md` for the full contract.
  """

  @doc false
  def contract_path, do: "docs/API-CONTRACT.md"
end

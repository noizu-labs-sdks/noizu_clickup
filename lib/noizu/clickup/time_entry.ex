defmodule Noizu.ClickUp.TimeEntry do
  @moduledoc """
  Time tracking entries and timers.

  Timestamps are Unix milliseconds. A negative `duration` means the timer is
  currently running. The date-range endpoint is not paginated (default window:
  last 30 days for the current user).
  """

  alias Noizu.ClickUp.Client
  alias Noizu.ClickUp.Error
  alias Noizu.ClickUp.Request

  @doc """
  Lists time entries within a date range.

  `GET /team/{team_id}/time_entries` — `params`: `:start_date`, `:end_date`
  (unix ms), `:assignee`, `:include_task_tags`, `:include_location_names`,
  exactly one of `:space_id`/`:folder_id`/`:list_id`/`:task_id`, `:is_billable`,
  `:custom_task_ids` (+ `:team_id`). Returns `{"data" => [...]}`.
  """
  @spec list(Client.t(), String.t() | integer(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list(client, team_id, params \\ []),
    do: Request.request(client, :get, "/team/#{team_id}/time_entries", params: params)

  @doc """
  Creates a time entry. `POST /team/{team_id}/time_entries`.

  `attrs` requires `start` and `duration`; optional `description`, `assignee`,
  `billable`, `tags`, `tid`, `stop`/`end`. `params` query: `:custom_task_ids`,
  `:team_id`. Returns the entry object (flat, no `data` wrapper).
  """
  @spec create(Client.t(), String.t() | integer(), map(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def create(client, team_id, attrs, params \\ []) do
    Request.request(client, :post, "/team/#{team_id}/time_entries", params: params, json: attrs)
  end

  @doc "Gets one time entry. `GET /team/{team_id}/time_entries/{timer_id}` — returns `{\"data\" => {...}}`."
  @spec get(Client.t(), String.t() | integer(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(client, team_id, timer_id),
    do: Request.request(client, :get, "/team/#{team_id}/time_entries/#{timer_id}")

  @doc """
  Updates a time entry. `PUT /team/{team_id}/time_entries/{timer_id}`.

  `attrs`: `tags` (required by the API), `tag_action` (`"replace"`/`"add"`/`"remove"`),
  `start` + `end` (together), `billable`, `tid`, `duration`. `params` query:
  `:custom_task_ids`, `:team_id`.
  """
  @spec update(Client.t(), String.t() | integer(), String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def update(client, team_id, timer_id, attrs, params \\ []) do
    Request.request(client, :put, "/team/#{team_id}/time_entries/#{timer_id}",
      params: params,
      json: attrs
    )
  end

  @doc "Deletes a time entry. `DELETE /team/{team_id}/time_entries/{timer_id}` — returns `{\"data\" => {...}}`."
  @spec delete(Client.t(), String.t() | integer(), String.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def delete(client, team_id, timer_id),
    do: Request.request(client, :delete, "/team/#{team_id}/time_entries/#{timer_id}")

  @doc "Starts a timer for the authenticated user. `POST /team/{team_id}/time_entries/start` — `attrs` optional (`description`, `billable`, `tags`, `tid`). Returns `{\"data\" => {...}}`."
  @spec start(Client.t(), String.t() | integer(), map(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def start(client, team_id, attrs \\ %{}, params \\ []) do
    Request.request(client, :post, "/team/#{team_id}/time_entries/start",
      params: params,
      json: attrs
    )
  end

  @doc "Stops the authenticated user's running timer. `POST /team/{team_id}/time_entries/stop` — returns `{\"data\" => {...}}`."
  @spec stop(Client.t(), String.t() | integer()) :: {:ok, map()} | {:error, Error.t()}
  def stop(client, team_id),
    do: Request.request(client, :post, "/team/#{team_id}/time_entries/stop")
end

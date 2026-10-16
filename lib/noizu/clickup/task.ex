defmodule Noizu.ClickUp.Task do
  @moduledoc """
  Tasks: CRUD, filtered workspace (team) task queries with pagination, and
  subtask access.

  Subtasks: `parent` in create attrs makes a subtask (same list); `include_subtasks`
  on `get/3` embeds a `subtasks` array; `parent`/`subtasks` filter team-task queries.
  """

  alias Noizu.ClickUp.Client
  alias Noizu.ClickUp.Error
  alias Noizu.ClickUp.Request

  @doc "Creates a task in a list. `POST /list/{list_id}/task` — `attrs` requires `name`. Returns the task object."
  @spec create(Client.t(), String.t() | integer(), map()) :: {:ok, map()} | {:error, Error.t()}
  def create(client, list_id, attrs),
    do: Request.request(client, :post, "/list/#{list_id}/task", json: attrs)

  @doc """
  Gets one task (object at top level, no wrapper).

  `GET /task/{task_id}` — `opts` query params: `:custom_task_ids` (requires
  `:team_id`), `:team_id`, `:include_subtasks`, `:include_markdown_description`.
  """
  @spec get(Client.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(client, task_id, opts \\ []),
    do: Request.request(client, :get, "/task/#{task_id}", params: opts)

  @doc "Updates a task. `PUT /task/{task_id}` — `attrs` partial; `opts` query params (`:custom_task_ids`, `:team_id`)."
  @spec update(Client.t(), String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def update(client, task_id, attrs, opts \\ []),
    do: Request.request(client, :put, "/task/#{task_id}", params: opts, json: attrs)

  @doc "Deletes a task (HTTP 204). `DELETE /task/{task_id}` — returns `{:ok, %{}}`."
  @spec delete(Client.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def delete(client, task_id, opts \\ []),
    do: Request.request(client, :delete, "/task/#{task_id}", params: opts)

  @doc """
  Gets one page of filtered workspace tasks.

  `GET /team/{team_id}/task` — `params` may include `:page` (starts at 0,
  max 100 tasks/page), `:statuses`, `:assignees`, `:tags`, `:space_ids`,
  `:project_ids`, `:list_ids`, `:parent`, `:subtasks`, `:include_closed`,
  `:order_by`, `:reverse`, `:due_date_gt`, `:due_date_lt`, `:date_created_gt`,
  `:date_created_lt`, `:date_updated_gt`, `:date_updated_lt`, `:date_done_gt`,
  `:date_done_lt`, `:custom_fields` (JSON string), `:custom_items`.

  List params are encoded as `key[]` repeated params. Returns
  `{"tasks" => [...], "last_page" => boolean}`.
  """
  @spec get_team_tasks(Client.t(), String.t() | integer(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def get_team_tasks(client, team_id, params \\ []),
    do: Request.request(client, :get, "/team/#{team_id}/task", params: params)

  @doc """
  Lazy stream over **all** filtered workspace tasks, paging with `page`
  until `last_page` is true (or an empty page arrives).

  Raises `%Noizu.ClickUp.Error{}` on request failure — use `get_team_tasks/3`
  for tuple semantics. See the pagination contract in `docs/API-CONTRACT.md`.
  """
  @spec stream_team_tasks(Client.t(), String.t() | integer(), keyword()) :: Enumerable.t()
  def stream_team_tasks(client, team_id, params \\ []) do
    Stream.resource(
      fn -> {:cont, 0} end,
      fn
        :done ->
          {:halt, :done}

        {:cont, page} ->
          case get_team_tasks(client, team_id, Keyword.put(params, :page, page)) do
            {:ok, body} when is_map(body) ->
              tasks = Map.get(body, "tasks", [])

              cond do
                tasks == [] -> {:halt, :done}
                body["last_page"] == true -> {tasks, :done}
                true -> {tasks, {:cont, page + 1}}
              end

            {:error, %Error{} = error} ->
              raise error

            {:ok, other} ->
              raise Error.exception(message: "unexpected team tasks response: #{inspect(other)}")
          end
      end,
      fn _ -> :ok end
    )
  end
end

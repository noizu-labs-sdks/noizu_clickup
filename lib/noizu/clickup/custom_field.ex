defmodule Noizu.ClickUp.CustomField do
  @moduledoc """
  Custom fields: accessible definitions per list, and value get/set/clear on tasks.

  Setting a value: `set_value/5` takes the **full request body** — at minimum
  `%{"value" => ...}`. The value shape depends on the field type (string for
  text/URL/email/phone/dropdown UUIDs, number, integer ms for dates, `[uuid]`
  for labels, `%{"add" => [], "rem" => []}` for relationships/people, etc.);
  include `"value_options"` alongside `"value"` for date-with-time. See
  `docs/API-CONTRACT.md` §3.7.
  """

  alias Noizu.ClickUp.Client
  alias Noizu.ClickUp.Error
  alias Noizu.ClickUp.Request

  @doc """
  Lists the custom fields accessible on a list (workspace-scoped fields included).

  `GET /list/{list_id}/field` — returns `{"fields" => [...]}`.
  """
  @spec list_accessible(Client.t(), String.t() | integer()) ::
          {:ok, map()} | {:error, Error.t()}
  def list_accessible(client, list_id),
    do: Request.request(client, :get, "/list/#{list_id}/field")

  @doc """
  Sets a custom field value on a task.

  `POST /task/{task_id}/field/{field_id}` — `body` is the full JSON body
  (e.g. `%{"value" => 42}`; atom top-level keys allowed). `opts` query params:
  `:custom_task_ids`, `:team_id`. Returns `{:ok, %{}}`.
  """
  @spec set_value(Client.t(), String.t(), String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def set_value(client, task_id, field_id, body, opts \\ []) do
    Request.request(client, :post, "/task/#{task_id}/field/#{field_id}", params: opts, json: body)
  end

  @doc """
  Clears a custom field value on a task (removes the value, not the field option).

  `DELETE /task/{task_id}/field/{field_id}` — returns `{:ok, %{}}`.
  """
  @spec remove_value(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def remove_value(client, task_id, field_id, opts \\ []),
    do: Request.request(client, :delete, "/task/#{task_id}/field/#{field_id}", params: opts)
end

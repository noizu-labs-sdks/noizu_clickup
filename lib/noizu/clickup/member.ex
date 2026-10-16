defmodule Noizu.ClickUp.Member do
  @moduledoc """
  Members with **explicit** access to a task or list (excludes access inherited
  from the workspace, folder, or space).
  """

  alias Noizu.ClickUp.Client
  alias Noizu.ClickUp.Error
  alias Noizu.ClickUp.Request

  @doc "Lists members of a task. `GET /task/{task_id}/member` — returns `{\"members\" => [...]}`."
  @spec list_task_members(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def list_task_members(client, task_id),
    do: Request.request(client, :get, "/task/#{task_id}/member")

  @doc "Lists members of a list. `GET /list/{list_id}/member` — returns `{\"members\" => [...]}`."
  @spec list_list_members(Client.t(), String.t() | integer()) ::
          {:ok, map()} | {:error, Error.t()}
  def list_list_members(client, list_id),
    do: Request.request(client, :get, "/list/#{list_id}/member")
end

defmodule Noizu.ClickUp.Workspace do
  @moduledoc """
  Workspaces — called "teams" throughout the ClickUp API (`team_id` == Workspace id).
  """

  alias Noizu.ClickUp.Client
  alias Noizu.ClickUp.Error
  alias Noizu.ClickUp.Request

  @doc """
  Lists the workspaces available to the authenticated user.

  `GET /team` — returns `{"teams" => [...]}` (each team includes its `members`).
  """
  @spec list_authorized(Client.t()) :: {:ok, map()} | {:error, Error.t()}
  def list_authorized(client), do: Request.request(client, :get, "/team")
end

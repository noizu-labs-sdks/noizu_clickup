defmodule Noizu.ClickUp.Space do
  @moduledoc "Spaces within a workspace."

  alias Noizu.ClickUp.Client
  alias Noizu.ClickUp.Error
  alias Noizu.ClickUp.Request

  @doc """
  Lists spaces in a workspace.

  `GET /team/{team_id}/space` — `opts` are query params (`:archived`).
  Returns `{"spaces" => [...]}`.
  """
  @spec list(Client.t(), String.t() | integer(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list(client, team_id, opts \\ []),
    do: Request.request(client, :get, "/team/#{Request.segment(team_id)}/space", params: opts)

  @doc "Gets one space. `GET /space/{space_id}` — returns the space object."
  @spec get(Client.t(), String.t() | integer()) :: {:ok, map()} | {:error, Error.t()}
  def get(client, space_id),
    do: Request.request(client, :get, "/space/#{Request.segment(space_id)}")

  @doc """
  Creates a space. `POST /team/{team_id}/space`.

  `attrs` requires `name`, `multiple_assignees`, `features` (ClickApp toggles).
  Returns the space object (no wrapper).
  """
  @spec create(Client.t(), String.t() | integer(), map()) :: {:ok, map()} | {:error, Error.t()}
  def create(client, team_id, attrs),
    do: Request.request(client, :post, "/team/#{Request.segment(team_id)}/space", json: attrs)

  @doc "Updates a space. `PUT /space/{space_id}` — `attrs` merged by the API."
  @spec update(Client.t(), String.t() | integer(), map()) :: {:ok, map()} | {:error, Error.t()}
  def update(client, space_id, attrs),
    do: Request.request(client, :put, "/space/#{Request.segment(space_id)}", json: attrs)

  @doc "Deletes a space. `DELETE /space/{space_id}` — returns `{:ok, %{}}`."
  @spec delete(Client.t(), String.t() | integer()) :: {:ok, map()} | {:error, Error.t()}
  def delete(client, space_id),
    do: Request.request(client, :delete, "/space/#{Request.segment(space_id)}")
end

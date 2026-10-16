defmodule Noizu.ClickUp.List do
  @moduledoc """
  Lists within folders or directly in spaces (folderless).

  Note: `status` on a List is its **color**, not task statuses.
  """

  alias Noizu.ClickUp.Client
  alias Noizu.ClickUp.Error
  alias Noizu.ClickUp.Request

  @doc "Lists lists in a folder. `GET /folder/{folder_id}/list` — `opts` query params (`:archived`). Returns `{\"lists\" => [...]}`."
  @spec list_in_folder(Client.t(), String.t() | integer(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def list_in_folder(client, folder_id, opts \\ []),
    do: Request.request(client, :get, "/folder/#{folder_id}/list", params: opts)

  @doc "Lists folderless lists in a space. `GET /space/{space_id}/list` — `opts` query params (`:archived`). Returns `{\"lists\" => [...]}`."
  @spec list_in_space(Client.t(), String.t() | integer(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def list_in_space(client, space_id, opts \\ []),
    do: Request.request(client, :get, "/space/#{space_id}/list", params: opts)

  @doc "Gets one list. `GET /list/{list_id}` — returns the list object."
  @spec get(Client.t(), String.t() | integer()) :: {:ok, map()} | {:error, Error.t()}
  def get(client, list_id), do: Request.request(client, :get, "/list/#{list_id}")

  @doc "Creates a list in a folder. `POST /folder/{folder_id}/list` — `attrs` requires `name`. Returns the list object."
  @spec create_in_folder(Client.t(), String.t() | integer(), map()) ::
          {:ok, map()} | {:error, Error.t()}
  def create_in_folder(client, folder_id, attrs),
    do: Request.request(client, :post, "/folder/#{folder_id}/list", json: attrs)

  @doc "Creates a folderless list in a space. `POST /space/{space_id}/list` — `attrs` requires `name`. Returns the list object."
  @spec create_in_space(Client.t(), String.t() | integer(), map()) ::
          {:ok, map()} | {:error, Error.t()}
  def create_in_space(client, space_id, attrs),
    do: Request.request(client, :post, "/space/#{space_id}/list", json: attrs)

  @doc "Updates a list. `PUT /list/{list_id}` — `attrs` requires `name`."
  @spec update(Client.t(), String.t() | integer(), map()) :: {:ok, map()} | {:error, Error.t()}
  def update(client, list_id, attrs),
    do: Request.request(client, :put, "/list/#{list_id}", json: attrs)

  @doc "Deletes a list. `DELETE /list/{list_id}` — returns `{:ok, %{}}`."
  @spec delete(Client.t(), String.t() | integer()) :: {:ok, map()} | {:error, Error.t()}
  def delete(client, list_id), do: Request.request(client, :delete, "/list/#{list_id}")
end

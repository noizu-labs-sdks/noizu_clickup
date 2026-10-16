defmodule Noizu.ClickUp.Folder do
  @moduledoc "Folders within a space."

  alias Noizu.ClickUp.Client
  alias Noizu.ClickUp.Error
  alias Noizu.ClickUp.Request

  @doc """
  Lists folders in a space (subfolders appear flat with a `parent_folder` field).

  `GET /space/{space_id}/folder` — `opts` are query params (`:archived`).
  Returns `{"folders" => [...]}`.
  """
  @spec list(Client.t(), String.t() | integer(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list(client, space_id, opts \\ []),
    do: Request.request(client, :get, "/space/#{space_id}/folder", params: opts)

  @doc "Gets one folder. `GET /folder/{folder_id}` — returns the folder object."
  @spec get(Client.t(), String.t() | integer()) :: {:ok, map()} | {:error, Error.t()}
  def get(client, folder_id), do: Request.request(client, :get, "/folder/#{folder_id}")

  @doc """
  Creates a folder. `POST /space/{space_id}/folder`.

  `attrs` requires `name`; optional `parent_folder_id` nests it (subfolders require
  workspace subfolder support). Returns the folder object.
  """
  @spec create(Client.t(), String.t() | integer(), map()) :: {:ok, map()} | {:error, Error.t()}
  def create(client, space_id, attrs),
    do: Request.request(client, :post, "/space/#{space_id}/folder", json: attrs)

  @doc """
  Renames a folder. `PUT /folder/{folder_id}` — only `name` is honored
  (`parent_folder_id` is ignored by the API; use Move Folder to relocate, not covered).
  """
  @spec update(Client.t(), String.t() | integer(), map()) :: {:ok, map()} | {:error, Error.t()}
  def update(client, folder_id, attrs),
    do: Request.request(client, :put, "/folder/#{folder_id}", json: attrs)

  @doc "Deletes a folder. `DELETE /folder/{folder_id}` — returns `{:ok, %{}}`."
  @spec delete(Client.t(), String.t() | integer()) :: {:ok, map()} | {:error, Error.t()}
  def delete(client, folder_id), do: Request.request(client, :delete, "/folder/#{folder_id}")
end

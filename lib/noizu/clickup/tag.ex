defmodule Noizu.ClickUp.Tag do
  @moduledoc """
  Tags: space-level tag CRUD and task tagging.

  Tag objects carry `name`, `tag_fg` (text color), `tag_bg` (background color).
  Note: ClickUp's Update Space Tag schema documents `fg_color`/`bg_color` while
  its examples show `tag_fg`/`tag_bg` — the body is passed through unchanged,
  so callers choose the keys.
  """

  alias Noizu.ClickUp.Client
  alias Noizu.ClickUp.Error
  alias Noizu.ClickUp.Request

  @doc "Lists a space's tags. `GET /space/{space_id}/tag` — returns `{\"tags\" => [...]}`."
  @spec list_space_tags(Client.t(), String.t() | integer()) :: {:ok, map()} | {:error, Error.t()}
  def list_space_tags(client, space_id),
    do: Request.request(client, :get, "/space/#{space_id}/tag")

  @doc "Creates a space tag. `POST /space/{space_id}/tag` — `tag_attrs` requires `name`, `tag_fg`, `tag_bg`. Returns `{:ok, %{}}`."
  @spec create_space_tag(Client.t(), String.t() | integer(), map()) ::
          {:ok, map()} | {:error, Error.t()}
  def create_space_tag(client, space_id, tag_attrs),
    do: Request.request(client, :post, "/space/#{space_id}/tag", json: %{tag: tag_attrs})

  @doc """
  Renames/recolors a space tag identified by its current `tag_name`.

  `PUT /space/{space_id}/tag/{tag_name}` — `tag_attrs` is the new tag body.
  """
  @spec update_space_tag(Client.t(), String.t() | integer(), String.t(), map()) ::
          {:ok, map()} | {:error, Error.t()}
  def update_space_tag(client, space_id, tag_name, tag_attrs) do
    Request.request(client, :put, "/space/#{space_id}/tag/#{encode(tag_name)}",
      json: %{tag: tag_attrs}
    )
  end

  @doc "Deletes a space tag. `DELETE /space/{space_id}/tag/{tag_name}` — returns `{:ok, %{}}`."
  @spec delete_space_tag(Client.t(), String.t() | integer(), String.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def delete_space_tag(client, space_id, tag_name),
    do: Request.request(client, :delete, "/space/#{space_id}/tag/#{encode(tag_name)}")

  @doc "Adds an existing space tag to a task. `POST /task/{task_id}/tag/{tag_name}` — returns `{:ok, %{}}`."
  @spec add_to_task(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def add_to_task(client, task_id, tag_name, opts \\ []),
    do: Request.request(client, :post, "/task/#{task_id}/tag/#{encode(tag_name)}", params: opts)

  @doc "Removes a tag from a task. `DELETE /task/{task_id}/tag/{tag_name}` — returns `{:ok, %{}}`."
  @spec remove_from_task(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def remove_from_task(client, task_id, tag_name, opts \\ []),
    do: Request.request(client, :delete, "/task/#{task_id}/tag/#{encode(tag_name)}", params: opts)

  defp encode(name), do: URI.encode(name, &URI.char_unreserved?/1)
end

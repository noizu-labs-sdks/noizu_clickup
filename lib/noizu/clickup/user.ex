defmodule Noizu.ClickUp.User do
  @moduledoc """
  The user tied to the client's token.
  """

  alias Noizu.ClickUp.Client
  alias Noizu.ClickUp.Error
  alias Noizu.ClickUp.Request

  @doc """
  Gets the authorized user.

  `GET /user` — returns `{"user" => %{...}}`.
  """
  @spec get(Client.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(client), do: Request.request(client, :get, "/user")
end

defmodule Noizu.ClickUp.OAuth do
  @moduledoc """
  OAuth 2.0 helpers: browser authorize URL and authorization-code exchange.

  The API itself uses `Authorization: Bearer <token>` — build the client with
  `Noizu.ClickUp.Client.new(token: token, auth_style: :bearer)`.
  """

  alias Noizu.ClickUp.Client
  alias Noizu.ClickUp.Error

  @authorize_base_url "https://app.clickup.com/api"

  @doc """
  Builds the user-consent URL.

  ## Options

    * `:client_id` (required) — OAuth app client id
    * `:redirect_uri` (required) — must be registered with the ClickUp app
    * `:state` — optional opaque value echoed back to the redirect

  ## Example

      Noizu.ClickUp.OAuth.authorize_url(
        client_id: "abc",
        redirect_uri: "https://my.app/clickup/callback",
        state: "csrf"
      )
  """
  @spec authorize_url(keyword()) :: String.t()
  def authorize_url(opts) when is_list(opts) do
    client_id = Keyword.fetch!(opts, :client_id)
    redirect_uri = Keyword.fetch!(opts, :redirect_uri)

    base_params = [
      {"client_id", client_id},
      {"redirect_uri", redirect_uri}
    ]

    params = if opts[:state], do: base_params ++ [{"state", opts[:state]}], else: base_params

    @authorize_base_url <> "?" <> URI.encode_query(params)
  end

  @doc """
  Exchanges an OAuth authorization code for an access token.

  `GET /oauth/token` with `client_id`, `client_secret`, `code` (ClickUp's
  documented form). Returns the decoded token response (includes
  `"access_token"`).

  ## Options

    * `:base_url` — override the API base (defaults to the standard v2 base)
    * `:req_options` — extra Req options merged into the request
  """
  @spec exchange_code(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def exchange_code(client_id, client_secret, code, opts \\ []) do
    req =
      [
        base_url: Keyword.get(opts, :base_url, Client.default_base_url()),
        url: "/oauth/token",
        retry: false,
        params: [
          client_id: client_id,
          client_secret: client_secret,
          code: code
        ]
      ]
      |> Req.new()
      |> Req.merge(Keyword.get(opts, :req_options, []))

    case Req.request(req) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, Error.from_response(status, body)}

      {:error, exception} ->
        {:error, Error.transport(exception)}
    end
  end
end

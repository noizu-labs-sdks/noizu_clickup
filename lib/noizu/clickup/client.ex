defmodule Noizu.ClickUp.Client do
  @moduledoc """
  Configuration struct passed explicitly to every API call.

  No global state is required. `new/0` reads optional defaults from
  `Application.get_env(:noizu_clickup, :client)` (a keyword list); options
  given to `new/1` win.

  ## Options

    * `:token` — API token: personal (`pk_...`) or OAuth access token (required
      for API calls; `Noizu.ClickUp.OAuth.exchange_code/4` needs no token)
    * `:auth_style` — `:personal` (default, raw `Authorization: pk_...` header)
      or `:bearer` (`Authorization: Bearer <token>`)
    * `:base_url` — default `"https://api.clickup.com/api/v2"`
    * `:req_options` — keyword list merged into every `Req.new/1` call; use it
      to inject `plug: {Req.Test, ...}` in tests or tune transport options
    * `:max_retries` — retries on HTTP 429 (default 2)
    * `:retry_cap_ms` — upper bound on the sleep between 429 retries
      (default 15_000)
  """

  @default_base_url "https://api.clickup.com/api/v2"

  defstruct token: nil,
            auth_style: :personal,
            base_url: @default_base_url,
            req_options: [],
            max_retries: 2,
            retry_cap_ms: 15_000

  @typedoc "Authentication header style."
  @type auth_style :: :personal | :bearer

  @type t :: %__MODULE__{
          token: String.t() | nil,
          auth_style: auth_style(),
          base_url: String.t(),
          req_options: keyword(),
          max_retries: non_neg_integer(),
          retry_cap_ms: pos_integer()
        }

  @doc """
  Builds a client from app-env defaults (`:noizu_clickup, :client`) if any.

  Raises `ArgumentError` if the resulting config has no token — build with
  `new(token: nil)` explicitly only for token-less calls such as
  `Noizu.ClickUp.OAuth.exchange_code/4`.
  """
  @spec new() :: t()
  def new, do: new([])

  @doc "Builds a client from options; see the module documentation."
  @spec new(keyword()) :: t()
  def new(opts) when is_list(opts) do
    defaults =
      :noizu_clickup
      |> Application.get_env(:client, [])
      |> List.wrap()

    struct!(__MODULE__, Keyword.merge(defaults, opts))
  end

  @doc false
  @spec default_base_url() :: String.t()
  def default_base_url, do: @default_base_url

  @doc false
  @spec authorization_headers(t()) :: [{String.t(), String.t()}]
  def authorization_headers(%__MODULE__{token: nil}) do
    raise ArgumentError,
          "no ClickUp token configured — pass token: to Noizu.ClickUp.Client.new/1 " <>
            "(or set :noizu_clickup, :client in the app env)"
  end

  def authorization_headers(%__MODULE__{token: token, auth_style: :personal})
      when is_binary(token),
      do: [{"authorization", token}]

  def authorization_headers(%__MODULE__{token: token, auth_style: :bearer})
      when is_binary(token),
      do: [{"authorization", "Bearer " <> token}]
end

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
    * `:retry_sleep` — sleep function invoked with the clamped wait (in ms)
      between 429 retries; defaults to `&Process.sleep/1`. Override in tests
      to observe waits without really sleeping.
  """

  @default_base_url "https://api.clickup.com/api/v2"

  defstruct token: nil,
            auth_style: :personal,
            base_url: @default_base_url,
            req_options: [],
            max_retries: 2,
            retry_cap_ms: 15_000,
            retry_sleep: &Process.sleep/1

  @typedoc "Authentication header style."
  @type auth_style :: :personal | :bearer

  @type t :: %__MODULE__{
          token: String.t() | nil,
          auth_style: auth_style(),
          base_url: String.t(),
          req_options: keyword(),
          max_retries: non_neg_integer(),
          retry_cap_ms: pos_integer(),
          retry_sleep: (pos_integer() -> any())
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

  @doc """
  Redacts a token for debug output (`inspect/2`, logs): at most the first four
  characters survive, suffixed with `[REDACTED]` — never the full secret.
  """
  @spec redacted_token(term()) :: String.t() | nil
  def redacted_token(nil), do: nil

  def redacted_token(token) when is_binary(token) do
    case String.split_at(token, 4) do
      {_prefix, ""} -> "[REDACTED]"
      {prefix, _rest} -> prefix <> "[REDACTED]"
    end
  end

  def redacted_token(_other), do: "[REDACTED]"

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

defimpl Inspect, for: Noizu.ClickUp.Client do
  # T-001: the struct carries a long-lived credential, so the default inspect
  # would print it into logs, telemetry, and crash reports. Only the token is
  # masked; every other field stays debuggable.
  def inspect(client, opts) do
    redacted = Noizu.ClickUp.Client.redacted_token(client.token)
    Inspect.Any.inspect(%{client | token: redacted}, opts)
  end
end

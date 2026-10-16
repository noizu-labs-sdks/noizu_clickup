defmodule Noizu.ClickUp.Request do
  @moduledoc false

  alias Noizu.ClickUp.Client
  alias Noizu.ClickUp.Error

  @rate_limit_reset_header "x-ratelimit-reset"
  @default_retry_wait_ms 1_000

  @doc """
  Performs one API call with bounded 429 retries.

  ## Options

    * `:params` — query parameters (keyword or map); list values are encoded as
      `key[]=value` pairs per ClickUp's convention
    * `:json` — request body (map with optional atom top-level keys); `nil` sends no body
  """
  @spec request(Client.t(), atom(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def request(client, method, path, opts \\ []) do
    params = encode_params(Keyword.get(opts, :params, []))
    json = stringify_json(Keyword.get(opts, :json))

    url =
      case params do
        [] -> path
        pairs -> path <> "?" <> encode_query_pairs(pairs)
      end

    do_request(client, method, url, json, 0)
  end

  # Keys are caller-controlled snake_case names (plus the "[]" ClickUp suffix),
  # so they pass through raw — matching the documented `statuses[]=to%20do` form.
  defp encode_query_pairs(pairs) do
    Enum.map_join(pairs, "&", fn {k, v} ->
      to_string(k) <> "=" <> URI.encode_www_form(to_string(v))
    end)
  end

  @doc """
  Encodes query params into flat `key=value` pairs: list values become repeated
  `key[]` pairs per ClickUp's convention.
  """
  @spec encode_params(keyword() | map()) :: [{String.t(), term()}]
  def encode_params(params) do
    Enum.flat_map(params, fn
      {k, v} when is_list(v) ->
        key = to_string(k) <> "[]"
        Enum.map(v, fn item -> {key, item} end)

      {k, v} ->
        [{to_string(k), v}]
    end)
  end

  defp do_request(client, method, url, json, attempt) do
    req =
      [
        base_url: client.base_url,
        method: method,
        url: url,
        headers: request_headers(client, json),
        retry: false
      ]
      |> then(fn base -> if json, do: Keyword.put(base, :json, json), else: base end)
      |> Req.new()
      |> Req.merge(client.req_options)

    case Req.request(req) do
      {:ok, %Req.Response{status: 429} = resp} ->
        rate_limited(client, method, url, json, attempt, resp)

      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, normalize_body(body)}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, Error.from_response(status, body)}

      {:error, exception} ->
        {:error, Error.transport(exception)}
    end
  end

  defp rate_limited(client, method, url, json, attempt, resp) do
    if attempt < client.max_retries do
      Process.sleep(retry_wait_ms(client, resp))
      do_request(client, method, url, json, attempt + 1)
    else
      {:error, Error.from_response(429, resp.body)}
    end
  end

  defp retry_wait_ms(client, resp) do
    case header(resp.headers, @rate_limit_reset_header) do
      nil ->
        @default_retry_wait_ms

      value ->
        case Integer.parse(to_string(value)) do
          {reset_epoch_seconds, _} ->
            (reset_epoch_seconds * 1000)
            |> Kernel.-(System.system_time(:millisecond))
            |> max(0)
            |> min(client.retry_cap_ms)

          :error ->
            @default_retry_wait_ms
        end
    end
  end

  defp header(headers, name) when is_list(headers) do
    case List.keyfind(headers, name, 0) do
      {_, [value | _]} -> value
      {_, value} when is_binary(value) -> value
      _ -> nil
    end
  end

  defp header(_, _), do: nil

  defp request_headers(client, json) do
    Client.authorization_headers(client) ++
      if json, do: [], else: [{"content-type", "application/json"}]
  end

  defp stringify_json(nil), do: nil

  defp stringify_json(body) when is_map(body),
    do: Map.new(body, fn {k, v} -> {to_string(k), v} end)

  defp stringify_json(other), do: other

  defp normalize_body(body) when body in [nil, ""], do: %{}
  defp normalize_body(body), do: body
end

defmodule Noizu.ClickUp.Request do
  @moduledoc false

  alias Noizu.ClickUp.Client
  alias Noizu.ClickUp.Error

  @rate_limit_reset_header "x-ratelimit-reset"
  @retry_after_header "retry-after"
  @default_retry_wait_ms 1_000
  # Reset values at/above this are Unix epoch seconds; smaller values arriving
  # in X-RateLimit-Reset are treated as "seconds until reset" instead of an
  # epoch in the past (which would floor the wait to 0 and hammer the API).
  @epoch_floor_seconds 1_000_000_000

  @doc """
  Encodes one caller-supplied resource id as a single URL path segment
  (T-005). Percent-encodes `/ ? # & = %`, spaces, and every other reserved
  character so a crafted id can neither traverse the path nor inject a query —
  `"1/../../team?x=1"` becomes `"1%2F..%2F..%2Fteam%3Fx%3D1"`.
  """
  @spec segment(term()) :: String.t()
  def segment(id)

  def segment(id) when is_binary(id), do: URI.encode(id, &URI.char_unreserved?/1)
  def segment(id) when is_integer(id), do: Integer.to_string(id)
  def segment(other), do: URI.encode(to_string(other), &URI.char_unreserved?/1)

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
      client.retry_sleep.(retry_wait_ms(client, resp.headers))
      do_request(client, method, url, json, attempt + 1)
    else
      {:error, Error.from_response(429, resp.body)}
    end
  end

  @doc """
  Milliseconds to sleep before a 429 retry, always clamped to `0..cap_ms`
  (`cap_ms` = the client's `retry_cap_ms`) so an untrusted reset value can
  never make the client sleep unboundedly or retry immediately.

  Resolution order:

    * `x-ratelimit-reset` — epoch seconds (values ≥ `#{@epoch_floor_seconds}`),
      else seconds-until-reset
    * `retry-after` — seconds
    * neither parseable → `#{@default_retry_wait_ms}` (also the default wait)
  """
  @spec retry_wait_ms(Client.t(), list() | map()) :: non_neg_integer()
  def retry_wait_ms(client, headers) do
    cap = max(client.retry_cap_ms, 0)
    now = System.system_time(:millisecond)

    cond do
      seconds = reset_seconds(headers, @rate_limit_reset_header) ->
        wait =
          if seconds >= @epoch_floor_seconds,
            do: seconds * 1000 - now,
            else: seconds * 1000

        clamp(wait, cap)

      seconds = reset_seconds(headers, @retry_after_header) ->
        clamp(seconds * 1000, cap)

      true ->
        @default_retry_wait_ms
    end
  end

  defp reset_seconds(headers, name) do
    case header(headers, name) do
      nil -> nil
      value -> parse_seconds(value)
    end
  end

  defp parse_seconds(value) do
    case Integer.parse(to_string(value)) do
      {seconds, _rest} -> seconds
      :error -> nil
    end
  end

  defp clamp(wait_ms, cap) when is_integer(wait_ms), do: wait_ms |> max(0) |> min(cap)

  # Req 0.7 response headers are maps of lowercase name => value list; accept
  # raw tuple lists too so retry_wait_ms/2 is testable either way.
  defp header(headers, name) when is_map(headers) do
    case Map.fetch(headers, name) do
      {:ok, [value | _]} -> value
      {:ok, value} when is_binary(value) -> value
      _ -> nil
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

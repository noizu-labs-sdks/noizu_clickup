defmodule Noizu.ClickUp.Webhook do
  @moduledoc """
  Webhooks: CRUD plus delivery-signature verification.

  Create returns the webhook's `secret`; each delivery carries an `X-Signature`
  header — the lowercase hex HMAC-SHA256 of the **raw request body**, keyed with
  that secret. Verify against raw bytes, never re-serialized JSON.
  """

  alias Noizu.ClickUp.Client
  alias Noizu.ClickUp.Error
  alias Noizu.ClickUp.Request

  @doc "Lists webhooks created by the authenticated user. `GET /team/{team_id}/webhook` — returns `{\"webhooks\" => [...]}`."
  @spec list(Client.t(), String.t() | integer()) :: {:ok, map()} | {:error, Error.t()}
  def list(client, team_id), do: Request.request(client, :get, "/team/#{team_id}/webhook")

  @doc """
  Creates a webhook. `POST /team/{team_id}/webhook`.

  `attrs` requires `endpoint` and `events` (`"*"` or event names like
  `"taskCreated"`); at most one of `space_id`/`folder_id`/`list_id`/`task_id`
  scopes the webhook. Returns `{"id" => ..., "webhook" => %{"secret" => ..., ...}}`.
  """
  @spec create(Client.t(), String.t() | integer(), map()) :: {:ok, map()} | {:error, Error.t()}
  def create(client, team_id, attrs),
    do: Request.request(client, :post, "/team/#{team_id}/webhook", json: attrs)

  @doc "Updates a webhook. `PUT /webhook/{webhook_id}` — `attrs`: `endpoint`, `events`, `status` (`\"active\"`/`\"inactive\"`)."
  @spec update(Client.t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def update(client, webhook_id, attrs),
    do: Request.request(client, :put, "/webhook/#{webhook_id}", json: attrs)

  @doc "Deletes a webhook. `DELETE /webhook/{webhook_id}` — returns `{:ok, %{}}`."
  @spec delete(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def delete(client, webhook_id), do: Request.request(client, :delete, "/webhook/#{webhook_id}")

  @doc """
  Verifies a webhook delivery signature (constant-time).

    * `secret` — the webhook's `secret` from create
    * `raw_body` — the **raw, unparsed** request body bytes
    * `signature` — the `X-Signature` header value (case-insensitive hex)

  Returns `true` only when the digests match; length or content mismatch → `false`.
  """
  @spec verify_signature(binary(), binary(), binary() | nil) :: boolean()
  def verify_signature(secret, raw_body, signature)
      when is_binary(secret) and is_binary(raw_body) do
    expected = Base.encode16(:crypto.mac(:hmac, :sha256, secret, raw_body), case: :lower)

    case signature do
      sig when is_binary(sig) ->
        given = String.downcase(sig)

        byte_size(given) == byte_size(expected) and
          :crypto.hash_equals(expected, given) == true

      _ ->
        false
    end
  end
end

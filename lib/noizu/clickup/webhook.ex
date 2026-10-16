defmodule Noizu.ClickUp.Webhook do
  @moduledoc """
  Webhooks: CRUD plus delivery-signature verification.

  Create returns the webhook's `secret`; each delivery carries an `X-Signature`
  header — the lowercase hex HMAC-SHA256 of the **raw request body**, keyed with
  that secret. Verify against raw bytes, never re-serialized JSON.

  ## Consumer obligations (T-003 — ClickUp's scheme has no anti-replay material)

  The signature covers the body only — no timestamp or nonce is signed, so a
  captured delivery would verify forever. The library cannot fix this
  unilaterally (it would need ClickUp to sign a timestamp); consumers must:

    * Verify against the **raw request body** — capture the bytes before
      `Plug.Parsers` (custom body reader / raw-body caching). Re-serialized
      JSON fails closed (returns `false`), never open.
    * **Dedupe deliveries**: persist processed ids and drop repeats, keyed on
      `webhook_id` + `event` plus the `history_items[].id` values in the
      payload — the standard mitigation against replays.
    * Treat handlers as idempotent (upsert semantics) so a replay is a no-op.

  See `docs/threats/webhook-signature.md` for the full analysis.
  """

  alias Noizu.ClickUp.Client
  alias Noizu.ClickUp.Error
  alias Noizu.ClickUp.Request

  @doc "Lists webhooks created by the authenticated user. `GET /team/{team_id}/webhook` — returns `{\"webhooks\" => [...]}`."
  @spec list(Client.t(), String.t() | integer()) :: {:ok, map()} | {:error, Error.t()}
  def list(client, team_id),
    do: Request.request(client, :get, "/team/#{Request.segment(team_id)}/webhook")

  @doc """
  Creates a webhook. `POST /team/{team_id}/webhook`.

  `attrs` requires `endpoint` and `events` (`"*"` or event names like
  `"taskCreated"`); at most one of `space_id`/`folder_id`/`list_id`/`task_id`
  scopes the webhook. Returns `{"id" => ..., "webhook" => %{"secret" => ..., ...}}`.
  """
  @spec create(Client.t(), String.t() | integer(), map()) :: {:ok, map()} | {:error, Error.t()}
  def create(client, team_id, attrs),
    do: Request.request(client, :post, "/team/#{Request.segment(team_id)}/webhook", json: attrs)

  @doc "Updates a webhook. `PUT /webhook/{webhook_id}` — `attrs`: `endpoint`, `events`, `status` (`\"active\"`/`\"inactive\"`)."
  @spec update(Client.t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def update(client, webhook_id, attrs),
    do: Request.request(client, :put, "/webhook/#{Request.segment(webhook_id)}", json: attrs)

  @doc "Deletes a webhook. `DELETE /webhook/{webhook_id}` — returns `{:ok, %{}}`."
  @spec delete(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def delete(client, webhook_id),
    do: Request.request(client, :delete, "/webhook/#{Request.segment(webhook_id)}")

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

defmodule Noizu.ClickUp.Comment do
  @moduledoc """
  Task comments, newest first (25 per page), with a cursor stream.

  Cursor model: `start` (date ms of the last comment) **plus** `start_id`
  (its id) fetch the next older page.
  """

  alias Noizu.ClickUp.Client
  alias Noizu.ClickUp.Error
  alias Noizu.ClickUp.Request

  @doc """
  Lists task comments. `GET /task/{task_id}/comment` — `params` query params:
  `:start` + `:start_id` (cursor pair), `:custom_task_ids`, `:team_id`.
  Returns `{"comments" => [...]}` ordered newest → oldest.
  """
  @spec list_task_comments(Client.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def list_task_comments(client, task_id, params \\ []),
    do: Request.request(client, :get, "/task/#{task_id}/comment", params: params)

  @doc """
  Creates a task comment. `POST /task/{task_id}/comment`.

  `attrs` requires `comment_text`; `notify_all` defaults to `true` when absent
  (the API requires the field). Returns `{"id" => ..., "hist_id" => ..., "date" => ...}`.
  """
  @spec create(Client.t(), String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create(client, task_id, attrs, opts \\ []) do
    attrs =
      attrs
      |> stringify()
      |> Map.put_new("notify_all", true)

    Request.request(client, :post, "/task/#{task_id}/comment", params: opts, json: attrs)
  end

  @doc "Updates a comment. `PUT /comment/{comment_id}` — `attrs`: `comment_text`, `assignee`, `resolved`."
  @spec update(Client.t(), String.t() | integer(), map()) :: {:ok, map()} | {:error, Error.t()}
  def update(client, comment_id, attrs),
    do: Request.request(client, :put, "/comment/#{comment_id}", json: attrs)

  @doc "Deletes a comment. `DELETE /comment/{comment_id}` — returns `{:ok, %{}}`."
  @spec delete(Client.t(), String.t() | integer()) :: {:ok, map()} | {:error, Error.t()}
  def delete(client, comment_id), do: Request.request(client, :delete, "/comment/#{comment_id}")

  @doc """
  Lazy stream over **all** task comments, walking older pages with the
  `start`/`start_id` cursor until an empty page.

  Raises `%Noizu.ClickUp.Error{}` on request failure — use
  `list_task_comments/3` for tuple semantics.
  """
  @spec stream_task_comments(Client.t(), String.t(), keyword()) :: Enumerable.t()
  def stream_task_comments(client, task_id, params \\ []) do
    Stream.resource(
      fn -> :start end,
      fn
        :done ->
          {:halt, :done}

        acc ->
          cursor_params =
            case acc do
              {:cursor, date, id} -> Keyword.merge(params, start: date, start_id: id)
              _ -> params
            end

          case list_task_comments(client, task_id, cursor_params) do
            {:ok, body} when is_map(body) ->
              comments = Map.get(body, "comments", [])

              cond do
                comments == [] ->
                  {:halt, :done}

                true ->
                  last = List.last(comments)
                  {comments, {:cursor, last["date"], last["id"]}}
              end

            {:error, %Error{} = error} ->
              raise error

            {:ok, other} ->
              raise Error.exception(message: "unexpected comments response: #{inspect(other)}")
          end
      end,
      fn _ -> :ok end
    )
  end

  defp stringify(attrs) when is_map(attrs),
    do: Map.new(attrs, fn {k, v} -> {to_string(k), v} end)
end

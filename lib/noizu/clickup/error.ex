defmodule Noizu.ClickUp.Error do
  @moduledoc """
  API and transport error returned as `{:error, %Noizu.ClickUp.Error{}}`.

    * `status` — HTTP status code, or `nil` for transport failures
    * `code` — ClickUp `ECODE` string (e.g. `"OAUTH_019"`) when the error body
      carries one, else `nil`
    * `message` — human-readable text from the error body

  The struct is an exception: raising it (streams do this on request failure)
  uses `message/1`.
  """

  defexception [:status, :code, :message]

  @type t :: %__MODULE__{
          status: non_neg_integer() | nil,
          code: String.t() | nil,
          message: String.t() | nil
        }

  @impl Exception
  @spec message(t()) :: String.t()
  def message(%__MODULE__{status: status, code: code, message: msg}) do
    IO.iodata_to_binary([
      "ClickUp request failed",
      if(status, do: " (HTTP #{status})", else: ""),
      if(code, do: " [#{code}]", else: ""),
      ": ",
      msg || "unknown error"
    ])
  end

  @doc false
  @spec from_response(non_neg_integer(), term()) :: t()
  def from_response(status, body) when is_map(body) do
    %__MODULE__{
      status: status,
      code: body["ECODE"],
      message: body["err"] || body["message"] || inspect(body)
    }
  end

  def from_response(status, body), do: %__MODULE__{status: status, message: short_inspect(body)}

  @doc false
  @spec transport(term()) :: t()
  def transport(exception) do
    %__MODULE__{status: nil, code: nil, message: exception_message(exception)}
  end

  defp exception_message(exception) when is_struct(exception) do
    module = exception.__struct__

    if function_exported?(module, :message, 1) do
      module.message(exception)
    else
      inspect(exception)
    end
  rescue
    _ -> inspect(exception)
  end

  defp exception_message(other), do: inspect(other)

  defp short_inspect(body) do
    inspected = inspect(body)

    if byte_size(inspected) > 500, do: binary_part(inspected, 0, 500) <> "…", else: inspected
  end
end

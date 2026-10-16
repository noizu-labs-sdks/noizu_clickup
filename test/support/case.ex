defmodule Noizu.ClickUp.Case do
  @moduledoc false

  use ExUnit.CaseTemplate

  import Plug.Conn

  using do
    quote do
      import Plug.Conn
      import Req.Test
      import Noizu.ClickUp.Case

      setup do
        client = stubbed_client()

        %{client: client, stub: Noizu.ClickUp.TestStub}
      end
    end
  end

  def stub, do: Noizu.ClickUp.TestStub

  @doc "Client pointed at a path-less stub host so conn.path_info matches our relative paths."
  def stubbed_client(extra \\ []) do
    Noizu.ClickUp.Client.new(
      Keyword.merge(
        [
          token: "pk_test_token",
          base_url: "https://api.clickup.test",
          req_options: [plug: {Req.Test, Noizu.ClickUp.TestStub}]
        ],
        extra
      )
    )
  end

  def assert_token(conn, expected \\ "pk_test_token") do
    assert {"authorization", expected} in conn.req_headers
    conn
  end

  def assert_method(conn, expected) do
    assert conn.method == expected
    conn
  end

  def assert_path(conn, expected) do
    assert conn.path_info == expected
    conn
  end

  def respond(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> resp(status, Jason.encode!(body))
  end

  def respond_rate_limited(conn, reset_epoch) do
    conn
    |> put_resp_header("x-ratelimit-reset", Integer.to_string(reset_epoch))
    |> put_resp_content_type("application/json")
    |> resp(429, Jason.encode!(%{"err" => "Rate limit exceeded.", "ECODE" => "RATE_LIMITED"}))
  end
end

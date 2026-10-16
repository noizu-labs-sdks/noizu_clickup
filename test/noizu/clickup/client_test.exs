defmodule Noizu.ClickUp.ClientTest do
  use Noizu.ClickUp.Case, async: true

  alias Noizu.ClickUp.Client

  describe "new/1" do
    test "applies defaults" do
      client = Client.new(token: "pk_x")
      assert client.base_url == "https://api.clickup.com/api/v2"
      assert client.auth_style == :personal
      assert client.max_retries == 2
      assert client.retry_cap_ms == 15_000
      assert client.req_options == []
    end

    test "explicit options win" do
      client = Client.new(token: "pk_x", auth_style: :bearer, base_url: "http://example.test")
      assert client.token == "pk_x"
      assert client.auth_style == :bearer
      assert client.base_url == "http://example.test"
    end

    test "new/0 reads app env defaults, explicit opts override" do
      Application.put_env(:noizu_clickup, :client,
        token: "pk_env",
        base_url: "http://env.test",
        max_retries: 7
      )

      on_exit(fn -> Application.delete_env(:noizu_clickup, :client) end)

      client = Client.new()
      assert client.token == "pk_env"
      assert client.base_url == "http://env.test"
      assert client.max_retries == 7

      assert %{token: "pk_explicit"} = Client.new(token: "pk_explicit")
    end
  end

  describe "authorization_headers/1" do
    test "personal style sends the raw token" do
      headers = Client.authorization_headers(%Client{token: "pk_abc", auth_style: :personal})
      assert headers == [{"authorization", "pk_abc"}]
    end

    test "bearer style prefixes Bearer" do
      headers = Client.authorization_headers(%Client{token: "tok", auth_style: :bearer})
      assert headers == [{"authorization", "Bearer tok"}]
    end

    test "raises on missing token" do
      assert_raise ArgumentError, ~r/no ClickUp token configured/, fn ->
        Client.authorization_headers(%Client{token: nil})
      end
    end
  end
end

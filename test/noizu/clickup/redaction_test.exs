defmodule Noizu.ClickUp.RedactionTest do
  use Noizu.ClickUp.Case, async: true

  alias Noizu.ClickUp.Client
  alias Noizu.ClickUp.Error
  alias Noizu.ClickUp.OAuth

  @token "pk_sup3rsecret_do_not_leak"

  describe "T-001 — %Client{} inspect redaction" do
    test "inspect/1 of a client never contains the raw token" do
      client = Client.new(token: @token)

      refute inspect(client) =~ @token
    end

    test "inspect/1 keeps a short debugging prefix and marks the token redacted" do
      client = Client.new(token: @token)

      assert inspect(client) =~ "token: \"pk_s"
      assert inspect(client) =~ "[REDACTED]"
    end

    test "inspect/1 of a client keeps the remaining fields debuggable" do
      client = Client.new(token: @token, auth_style: :bearer, max_retries: 5)

      inspected = inspect(client)

      assert inspected =~ "auth_style: :bearer"
      assert inspected =~ "max_retries: 5"
      assert inspected =~ "base_url: \"https://api.clickup.com/api/v2\""
    end

    test "inspect/1 of a token-less client shows nil, not a placeholder" do
      client = Client.new(token: nil)

      assert inspect(client) =~ "token: nil"
      refute inspect(client) =~ "[REDACTED]"
    end
  end

  describe "secrets in error paths" do
    test "a failed API call never surfaces the client token in the error", %{
      stub: stub
    } do
      client = stubbed_client(token: @token)

      Req.Test.expect(stub, fn conn ->
        conn
        |> put_resp_content_type("text/plain")
        |> resp(500, "boom")
      end)

      assert {:error, %Error{} = error} = Noizu.ClickUp.User.get(client)

      refute inspect(error) =~ @token
      refute Error.message(error) =~ @token
    end

    test "a failed OAuth exchange never surfaces the client_secret in the error", %{
      stub: stub
    } do
      Req.Test.expect(stub, fn conn ->
        conn
        |> put_resp_content_type("application/json")
        |> resp(400, Jason.encode!(%{"ECODE" => "OAUTH_019", "err" => "invalid code"}))
      end)

      assert {:error, %Error{} = error} =
               OAuth.exchange_code("cid", "sup3r_client_secret", "authcode",
                 req_options: [plug: {Req.Test, stub}]
               )

      refute inspect(error) =~ "sup3r_client_secret"
      refute Error.message(error) =~ "sup3r_client_secret"
    end
  end
end

defmodule Noizu.ClickUp.OAuthTest do
  use Noizu.ClickUp.Case, async: true

  alias Noizu.ClickUp.OAuth

  describe "authorize_url/1" do
    test "includes client_id, redirect_uri and state" do
      url =
        OAuth.authorize_url(
          client_id: "cid",
          redirect_uri: "https://my.app/cb",
          state: "csrf-token"
        )

      assert url =~ ~r{^https://app\.clickup\.com/api\?}
      assert url =~ "client_id=cid"
      assert url =~ URI.encode_www_form("https://my.app/cb")
      assert url =~ "state=csrf-token"
    end

    test "omits state when not given" do
      refute OAuth.authorize_url(client_id: "cid", redirect_uri: "https://my.app/cb")
             |> String.contains?("state=")
    end

    test "raises on missing required options" do
      assert_raise KeyError, fn -> OAuth.authorize_url(client_id: "cid") end
    end
  end

  describe "exchange_code/4" do
    test "GETs /oauth/token with credentials and returns the token body", %{stub: stub} do
      Req.Test.expect(stub, fn conn ->
        assert conn.method == "GET"
        assert conn.path_info == ["oauth", "token"]
        assert conn.query_params["client_id"] == "cid"
        assert conn.query_params["client_secret"] == "csecret"
        assert conn.query_params["code"] == "authcode"

        Req.Test.json(conn, %{"access_token" => "at_123"})
      end)

      assert {:ok, %{"access_token" => "at_123"}} =
               OAuth.exchange_code("cid", "csecret", "authcode",
                 base_url: "https://api.clickup.test",
                 req_options: [plug: {Req.Test, stub}]
               )
    end

    test "surfaces error responses", %{stub: stub} do
      Req.Test.expect(stub, fn conn ->
        respond(conn, 400, %{"err" => "Invalid code", "ECODE" => "OAUTH_007"})
      end)

      assert {:error, %Noizu.ClickUp.Error{status: 400, code: "OAUTH_007"}} =
               OAuth.exchange_code("cid", "csecret", "bad",
                 base_url: "https://api.clickup.test",
                 req_options: [plug: {Req.Test, stub}]
               )
    end
  end
end

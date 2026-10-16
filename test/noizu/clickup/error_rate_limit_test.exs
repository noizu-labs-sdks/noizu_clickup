defmodule Noizu.ClickUp.ErrorRateLimitTest do
  use Noizu.ClickUp.Case, async: true

  alias Noizu.ClickUp.Error

  describe "error decoding" do
    test "maps err/ECODE/message into the struct", %{client: client, stub: stub} do
      Req.Test.expect(stub, fn conn ->
        respond(conn, 400, %{
          "err" => "Custom Field not applicable",
          "ECODE" => "CF003",
          "message" => "not applicable to task type"
        })
      end)

      assert {:error,
              %Error{
                status: 400,
                code: "CF003",
                message: "Custom Field not applicable"
              }} = Noizu.ClickUp.User.get(client)
    end

    test "non-map error bodies degrade gracefully", %{client: client, stub: stub} do
      Req.Test.expect(stub, fn conn ->
        conn
        |> put_resp_content_type("text/plain")
        |> resp(502, "bad gateway")
      end)

      assert {:error, %Error{status: 502, code: nil, message: msg}} =
               Noizu.ClickUp.User.get(client)

      assert msg =~ "bad gateway"
    end

    test "message/1 renders status and code" do
      error = Error.exception(status: 404, code: "OAUTH_019", message: "Token not found")

      assert Error.message(error) ==
               "ClickUp request failed (HTTP 404) [OAUTH_019]: Token not found"
    end
  end

  describe "429 retry" do
    test "retries once after reset epoch has passed, then succeeds", %{
      client: client,
      stub: stub
    } do
      past = System.system_time(:second) - 10

      Req.Test.expect(stub, fn conn -> respond_rate_limited(conn, past) end)
      Req.Test.expect(stub, fn conn -> Req.Test.json(conn, %{"user" => %{"id" => 1}}) end)

      assert {:ok, %{"user" => %{"id" => 1}}} = Noizu.ClickUp.User.get(client)
    end

    test "returns the 429 as an error once retries are exhausted", %{stub: stub} do
      client = stubbed_client(max_retries: 1, retry_cap_ms: 1)
      past = System.system_time(:second) - 10

      Req.Test.expect(stub, 2, fn conn -> respond_rate_limited(conn, past) end)

      assert {:error, %Error{status: 429}} = Noizu.ClickUp.User.get(client)
    end

    test "caps the wait using retry_cap_ms when reset is in the future", %{stub: stub} do
      client = stubbed_client(retry_cap_ms: 1)
      future = System.system_time(:second) + 3_600

      Req.Test.expect(stub, fn conn -> respond_rate_limited(conn, future) end)
      Req.Test.expect(stub, fn conn -> Req.Test.json(conn, %{"ok" => true}) end)

      assert {:ok, %{"ok" => true}} = Noizu.ClickUp.User.get(client)
    end
  end
end

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

    test "the retry sleep is injectable and receives the clamped wait", %{stub: stub} do
      parent = self()

      client =
        stubbed_client(
          retry_cap_ms: 50,
          retry_sleep: fn ms -> send(parent, {:slept, ms}) end
        )

      far_future = System.system_time(:second) + 3_600

      Req.Test.expect(stub, fn conn -> respond_rate_limited(conn, far_future) end)
      Req.Test.expect(stub, fn conn -> Req.Test.json(conn, %{"ok" => true}) end)

      assert {:ok, %{"ok" => true}} = Noizu.ClickUp.User.get(client)
      assert_received {:slept, 50}
    end
  end

  describe "retry_wait_ms/2 clamping (X-RateLimit-Reset / Retry-After)" do
    alias Noizu.ClickUp.Request

    defp wait(headers, opts \\ []), do: Request.retry_wait_ms(stubbed_client(opts), headers)

    test "reset in the past computes a negative wait and floors to 0" do
      past = System.system_time(:second) - 100
      assert wait([{"x-ratelimit-reset", Integer.to_string(past)}]) == 0
    end

    test "explicitly negative reset floors to 0" do
      assert wait([{"x-ratelimit-reset", "-42"}]) == 0
    end

    test "far-future reset is clamped to retry_cap_ms" do
      far_future = System.system_time(:second) + 86_400
      assert wait([{"x-ratelimit-reset", Integer.to_string(far_future)}]) == 15_000

      assert wait([{"x-ratelimit-reset", Integer.to_string(far_future)}], retry_cap_ms: 250) ==
               250
    end

    test "garbage reset falls back to the default wait" do
      assert wait([{"x-ratelimit-reset", "soon"}]) == 1_000
      assert wait([{"x-ratelimit-reset", ""}]) == 1_000
    end

    test "missing header falls back to the default wait" do
      assert wait([]) == 1_000
    end

    test "Req's map-shaped response headers are honored too" do
      far_future = System.system_time(:second) + 86_400

      assert wait(%{"x-ratelimit-reset" => [Integer.to_string(far_future)]}) == 15_000
      assert wait(%{"retry-after" => ["30"]}) == 15_000
      assert wait(%{"x-ratelimit-reset" => ["0"]}) == 0
    end

    test "small reset values are treated as seconds-until-reset, not epochs" do
      # A proxy sending "90" as a delta must not be read as an epoch in the past
      # (which would floor to 0 and hammer the API with immediate retries).
      assert wait([{"x-ratelimit-reset", "90"}]) == 15_000
      assert wait([{"x-ratelimit-reset", "90"}], retry_cap_ms: 250) == 250
    end

    test "Retry-After seconds is honored and clamped as a fallback" do
      assert wait([{"retry-after", "30"}]) == 15_000
      assert wait([{"retry-after", "2"}], retry_cap_ms: 250) == 250
      assert wait([{"retry-after", "1"}]) == 1_000
    end

    test "garbage Retry-After falls back to the default wait" do
      assert wait([{"retry-after", "Friday, Dec 31 1999 23:59:59 GMT"}]) == 1_000
    end

    test "X-RateLimit-Reset wins over Retry-After" do
      assert wait([{"retry-after", "30"}, {"x-ratelimit-reset", "0"}]) == 0
    end
  end
end

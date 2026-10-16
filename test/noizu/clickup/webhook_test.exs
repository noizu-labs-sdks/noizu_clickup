defmodule Noizu.ClickUp.WebhookTest do
  use Noizu.ClickUp.Case, async: true

  alias Noizu.ClickUp.Webhook

  describe "CRUD" do
    test "list/2", %{client: client, stub: stub} do
      Req.Test.expect(stub, fn conn ->
        conn
        |> assert_path(["team", "123", "webhook"])
        |> Req.Test.json(%{
          "webhooks" => [
            %{
              "id" => "7689a169-a000-4985-8676-6902b96d6627",
              "endpoint" => "https://my.app/hook",
              "events" => ["taskCreated"],
              "health" => %{"status" => "active", "fail_count" => 0},
              "secret" => "s3cr3t"
            }
          ]
        })
      end)

      assert {:ok, %{"webhooks" => [%{"secret" => "s3cr3t"}]}} = Webhook.list(client, 123)
    end

    test "create/3 returns the webhook with its secret", %{client: client, stub: stub} do
      Req.Test.expect(stub, fn conn ->
        assert conn.body_params["endpoint"] == "https://my.app/hook"
        assert conn.body_params["events"] == ["taskCreated"]

        conn
        |> assert_method("POST")
        |> assert_path(["team", "123", "webhook"])
        |> Req.Test.json(%{
          "id" => "wh-1",
          "webhook" => %{"id" => "wh-1", "secret" => "s3cr3t"}
        })
      end)

      assert {:ok, %{"webhook" => %{"secret" => "s3cr3t"}}} =
               Webhook.create(client, 123, %{
                 endpoint: "https://my.app/hook",
                 events: ["taskCreated"]
               })
    end

    test "update/3 and delete/2", %{client: client, stub: stub} do
      Req.Test.expect(stub, fn conn ->
        assert conn.body_params["status"] == "active"

        conn
        |> assert_method("PUT")
        |> assert_path(["webhook", "wh-1"])
        |> Req.Test.json(%{"id" => "wh-1", "webhook" => %{"id" => "wh-1"}})
      end)

      Req.Test.expect(stub, fn conn ->
        conn
        |> assert_method("DELETE")
        |> assert_path(["webhook", "wh-1"])
        |> Req.Test.json(%{})
      end)

      assert {:ok, %{"webhook" => %{"id" => "wh-1"}}} =
               Webhook.update(client, "wh-1", %{status: "active"})

      assert {:ok, %{}} = Webhook.delete(client, "wh-1")
    end
  end

  describe "verify_signature/3" do
    @secret "whsec_123"
    @body ~s({"webhook_id":"7689a169","event":"taskCreated","task_id":"c0j"})

    defp sign(secret, body),
      do: Base.encode16(:crypto.mac(:hmac, :sha256, secret, body), case: :lower)

    test "accepts a valid lowercase signature" do
      assert Webhook.verify_signature(@secret, @body, sign(@secret, @body))
    end

    test "accepts uppercase hex" do
      sig = @secret |> sign(@body) |> String.upcase()
      assert Webhook.verify_signature(@secret, @body, sig)
    end

    test "rejects a wrong secret" do
      refute Webhook.verify_signature("other", @body, sign(@secret, @body))
    end

    test "rejects a tampered body" do
      assert Webhook.verify_signature(@secret, @body, sign(@secret, @body))
      refute Webhook.verify_signature(@secret, @body <> " ", sign(@secret, @body))
    end

    test "rejects wrong length and missing signatures" do
      refute Webhook.verify_signature(@secret, @body, "abcd")
      refute Webhook.verify_signature(@secret, @body, nil)
    end
  end
end

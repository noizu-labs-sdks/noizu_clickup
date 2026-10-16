defmodule Noizu.ClickUp.CustomFieldTest do
  use Noizu.ClickUp.Case, async: true

  alias Noizu.ClickUp.CustomField

  test "list_accessible/2 returns fields", %{client: client, stub: stub} do
    Req.Test.expect(stub, fn conn ->
      conn
      |> assert_method("GET")
      |> assert_path(["list", "987", "field"])
      |> Req.Test.json(%{
        "fields" => [%{"id" => "uuid-1", "name" => "Points", "type" => "number"}]
      })
    end)

    assert {:ok, %{"fields" => [%{"id" => "uuid-1"}]}} = CustomField.list_accessible(client, 987)
  end

  test "set_value/5 posts the full body with query opts", %{client: client, stub: stub} do
    Req.Test.expect(stub, fn conn ->
      assert conn.body_params["value"] == 42
      assert conn.query_params["custom_task_ids"] == "true"
      assert conn.query_params["team_id"] == "123"

      conn
      |> assert_method("POST")
      |> assert_path(["task", "9hz", "field", "uuid-1"])
      |> Req.Test.json(%{})
    end)

    assert {:ok, %{}} =
             CustomField.set_value(client, "9hz", "uuid-1", %{value: 42},
               custom_task_ids: true,
               team_id: 123
             )
  end

  test "remove_value/4 clears the value", %{client: client, stub: stub} do
    Req.Test.expect(stub, fn conn ->
      conn
      |> assert_method("DELETE")
      |> assert_path(["task", "9hz", "field", "uuid-1"])
      |> Req.Test.json(%{})
    end)

    assert {:ok, %{}} = CustomField.remove_value(client, "9hz", "uuid-1")
  end
end

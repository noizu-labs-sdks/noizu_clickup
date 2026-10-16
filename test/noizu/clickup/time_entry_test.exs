defmodule Noizu.ClickUp.TimeEntryTest do
  use Noizu.ClickUp.Case, async: true

  alias Noizu.ClickUp.TimeEntry

  test "list/3 hits the date-range endpoint with params", %{client: client, stub: stub} do
    Req.Test.expect(stub, fn conn ->
      assert conn.query_params["start_date"] == "1595282645000"
      assert conn.query_params["include_location_names"] == "true"

      conn
      |> assert_path(["team", "123", "time_entries"])
      |> Req.Test.json(%{"data" => [%{"id" => "55", "duration" => 5000}]})
    end)

    assert {:ok, %{"data" => [%{"id" => "55"}]}} =
             TimeEntry.list(client, 123,
               start_date: 1_595_282_645_000,
               include_location_names: true
             )
  end

  test "create/4 posts start+duration, response is flat", %{client: client, stub: stub} do
    Req.Test.expect(stub, fn conn ->
      assert conn.body_params["start"] == 1_595_282_645_000
      assert conn.body_params["duration"] == 50_000

      conn
      |> assert_method("POST")
      |> assert_path(["team", "123", "time_entries"])
      |> Req.Test.json(%{"id" => "55", "duration" => 50_000})
    end)

    assert {:ok, %{"id" => "55"}} =
             TimeEntry.create(client, 123, %{"start" => 1_595_282_645_000, "duration" => 50_000})
  end

  test "get/3, update/5, delete/3", %{client: client, stub: stub} do
    Req.Test.expect(stub, fn conn ->
      conn
      |> assert_path(["team", "123", "time_entries", "55"])
      |> Req.Test.json(%{"data" => %{"id" => "55"}})
    end)

    Req.Test.expect(stub, fn conn ->
      assert conn.body_params["tag_action"] == "add"

      conn
      |> assert_method("PUT")
      |> assert_path(["team", "123", "time_entries", "55"])
      |> Req.Test.json(%{})
    end)

    Req.Test.expect(stub, fn conn ->
      conn
      |> assert_method("DELETE")
      |> assert_path(["team", "123", "time_entries", "55"])
      |> Req.Test.json(%{"data" => %{"id" => "55"}})
    end)

    assert {:ok, %{"data" => %{"id" => "55"}}} = TimeEntry.get(client, 123, "55")

    assert {:ok, %{}} =
             TimeEntry.update(client, 123, "55", %{tag_action: "add", tags: [%{name: "t"}]})

    assert {:ok, %{"data" => %{"id" => "55"}}} = TimeEntry.delete(client, 123, "55")
  end

  test "start/4 and stop/2", %{client: client, stub: stub} do
    Req.Test.expect(stub, fn conn ->
      assert conn.body_params["description"] == "from api"

      conn
      |> assert_method("POST")
      |> assert_path(["team", "123", "time_entries", "start"])
      |> Req.Test.json(%{"data" => %{"id" => "56", "duration" => -53}})
    end)

    Req.Test.expect(stub, fn conn ->
      conn
      |> assert_method("POST")
      |> assert_path(["team", "123", "time_entries", "stop"])
      |> Req.Test.json(%{"data" => %{"id" => "56", "duration" => 5_694_832}})
    end)

    assert {:ok, %{"data" => %{"duration" => -53}}} =
             TimeEntry.start(client, 123, %{description: "from api"})

    assert {:ok, %{"data" => %{"id" => "56"}}} = TimeEntry.stop(client, 123)
  end
end

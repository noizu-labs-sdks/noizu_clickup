defmodule Noizu.ClickUp.TaskTest do
  use Noizu.ClickUp.Case, async: true

  alias Noizu.ClickUp.Error
  alias Noizu.ClickUp.Task

  test "create/3 posts to the list with attrs", %{client: client, stub: stub} do
    Req.Test.expect(stub, fn conn ->
      assert conn.body_params["name"] == "Ship it"
      assert conn.body_params["parent"] == "9hp"

      conn
      |> assert_method("POST")
      |> assert_path(["list", "987", "task"])
      |> Req.Test.json(%{"id" => "9hz", "name" => "Ship it"})
    end)

    assert {:ok, %{"id" => "9hz"}} =
             Task.create(client, 987, %{"name" => "Ship it", "parent" => "9hp"})
  end

  test "get/3 passes subtask and custom-id params", %{client: client, stub: stub} do
    Req.Test.expect(stub, fn conn ->
      assert conn.query_params["include_subtasks"] == "true"
      assert conn.query_params["custom_task_ids"] == "true"
      assert conn.query_params["team_id"] == "123"

      conn
      |> assert_path(["task", "9hz"])
      |> Req.Test.json(%{"id" => "9hz", "subtasks" => [%{"id" => "9i0"}]})
    end)

    assert {:ok, %{"subtasks" => [%{"id" => "9i0"}]}} =
             Task.get(client, "9hz",
               include_subtasks: true,
               custom_task_ids: true,
               team_id: 123
             )
  end

  test "update/4 and delete/3", %{client: client, stub: stub} do
    Req.Test.expect(stub, fn conn ->
      assert conn.body_params["status"] == "closed"

      conn
      |> assert_method("PUT")
      |> assert_path(["task", "9hz"])
      |> Req.Test.json(%{"id" => "9hz", "status" => %{"status" => "closed"}})
    end)

    Req.Test.expect(stub, fn conn ->
      conn
      |> assert_method("DELETE")
      |> assert_path(["task", "9hz"])
      |> send_resp(204, "")
    end)

    assert {:ok, %{"id" => "9hz"}} = Task.update(client, "9hz", %{status: "closed"})
    assert {:ok, %{}} = Task.delete(client, "9hz")
  end

  describe "get_team_tasks/3" do
    test "encodes list filters as key[]= params", %{client: client, stub: stub} do
      Req.Test.expect(stub, fn conn ->
        # Plug decodes "statuses[]=a&statuses[]=b" into a list under "statuses";
        # assert the wire form carries the bracketed key ClickUp requires.
        assert conn.query_params["statuses"] == ["to do", "in progress"]
        assert conn.query_string =~ "statuses[]=to+do"
        assert conn.query_string =~ "statuses[]=in+progress"
        assert conn.query_params["page"] == "0"
        assert conn.query_params["subtasks"] == "true"

        conn
        |> assert_path(["team", "123", "task"])
        |> Req.Test.json(%{"tasks" => [%{"id" => "a"}], "last_page" => true})
      end)

      assert {:ok, %{"tasks" => [%{"id" => "a"}], "last_page" => true}} =
               Task.get_team_tasks(client, 123,
                 statuses: ["to do", "in progress"],
                 subtasks: true,
                 page: 0
               )
    end
  end

  describe "stream_team_tasks/3" do
    test "walks pages until last_page", %{client: client, stub: stub} do
      Req.Test.expect(stub, fn conn ->
        assert conn.query_params["page"] == "0"

        conn
        |> assert_path(["team", "123", "task"])
        |> Req.Test.json(%{"tasks" => [%{"id" => "a"}], "last_page" => false})
      end)

      Req.Test.expect(stub, fn conn ->
        assert conn.query_params["page"] == "1"

        conn
        |> Req.Test.json(%{"tasks" => [%{"id" => "b"}], "last_page" => true})
      end)

      assert [%{"id" => "a"}, %{"id" => "b"}] =
               client |> Task.stream_team_tasks(123) |> Enum.to_list()
    end

    test "stops on an empty page when last_page is absent", %{client: client, stub: stub} do
      Req.Test.expect(stub, fn conn ->
        Req.Test.json(conn, %{"tasks" => [%{"id" => "a"}]})
      end)

      Req.Test.expect(stub, fn conn -> Req.Test.json(conn, %{"tasks" => []}) end)

      assert [%{"id" => "a"}] = client |> Task.stream_team_tasks(123) |> Enum.to_list()
    end

    test "raises the ClickUp error on failure", %{stub: stub} do
      client = stubbed_client(max_retries: 0)
      past = System.system_time(:second) - 10

      Req.Test.expect(stub, fn conn -> respond_rate_limited(conn, past) end)

      assert_raise Error, ~r/429/, fn ->
        client |> Task.stream_team_tasks(123) |> Enum.to_list()
      end
    end
  end
end

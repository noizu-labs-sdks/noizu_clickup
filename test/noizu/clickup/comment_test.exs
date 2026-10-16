defmodule Noizu.ClickUp.CommentTest do
  use Noizu.ClickUp.Case, async: true

  alias Noizu.ClickUp.Comment

  test "list_task_comments/3", %{client: client, stub: stub} do
    Req.Test.expect(stub, fn conn ->
      conn
      |> assert_method("GET")
      |> assert_path(["task", "9hz", "comment"])
      |> Req.Test.json(%{"comments" => [%{"id" => "1", "comment_text" => "hi"}]})
    end)

    assert {:ok, %{"comments" => [%{"id" => "1"}]}} = Comment.list_task_comments(client, "9hz")
  end

  test "create/4 defaults notify_all and returns the id", %{client: client, stub: stub} do
    Req.Test.expect(stub, fn conn ->
      assert conn.body_params["comment_text"] == "Hello"
      assert conn.body_params["notify_all"] == true

      conn
      |> assert_method("POST")
      |> assert_path(["task", "9hz", "comment"])
      |> Req.Test.json(%{"id" => "458", "hist_id" => "26508", "date" => 1_568_036_964_079})
    end)

    assert {:ok, %{"id" => "458"}} = Comment.create(client, "9hz", %{comment_text: "Hello"})
  end

  test "update/3 and delete/2", %{client: client, stub: stub} do
    Req.Test.expect(stub, fn conn ->
      assert conn.body_params["comment_text"] == "Updated"
      assert conn.body_params["resolved"] == true

      conn
      |> assert_method("PUT")
      |> assert_path(["comment", "456"])
      |> Req.Test.json(%{"id" => "456"})
    end)

    Req.Test.expect(stub, fn conn ->
      conn
      |> assert_method("DELETE")
      |> assert_path(["comment", "456"])
      |> Req.Test.json(%{})
    end)

    assert {:ok, %{"id" => "456"}} =
             Comment.update(client, 456, %{comment_text: "Updated", resolved: true})

    assert {:ok, %{}} = Comment.delete(client, 456)
  end

  describe "stream_task_comments/3" do
    test "walks older pages with the start/start_id cursor", %{client: client, stub: stub} do
      Req.Test.expect(stub, fn conn ->
        refute Map.has_key?(conn.query_params, "start")

        conn
        |> assert_path(["task", "9hz", "comment"])
        |> Req.Test.json(%{
          "comments" => [
            %{"id" => "c1", "date" => 300},
            %{"id" => "c2", "date" => 200}
          ]
        })
      end)

      Req.Test.expect(stub, fn conn ->
        assert conn.query_params["start"] == "200"
        assert conn.query_params["start_id"] == "c2"

        conn
        |> Req.Test.json(%{"comments" => [%{"id" => "c3", "date" => 100}]})
      end)

      Req.Test.expect(stub, fn conn ->
        assert conn.query_params["start"] == "100"
        assert conn.query_params["start_id"] == "c3"

        conn
        |> Req.Test.json(%{"comments" => []})
      end)

      ids = client |> Comment.stream_task_comments("9hz") |> Enum.map(& &1["id"])
      assert ids == ["c1", "c2", "c3"]
    end
  end
end

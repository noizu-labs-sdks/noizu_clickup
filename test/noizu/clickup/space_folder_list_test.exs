defmodule Noizu.ClickUp.SpaceFolderListTest do
  use Noizu.ClickUp.Case, async: true

  alias Noizu.ClickUp.Folder
  alias Noizu.ClickUp.List
  alias Noizu.ClickUp.Space

  describe "Space" do
    test "list/3 hits GET /team/:team_id/space with archived", %{client: client, stub: stub} do
      Req.Test.expect(stub, fn conn ->
        assert conn.query_params["archived"] == "true"

        conn
        |> assert_method("GET")
        |> assert_path(["team", "123", "space"])
        |> Req.Test.json(%{"spaces" => [%{"id" => "790", "name" => "Eng"}]})
      end)

      assert {:ok, %{"spaces" => [%{"id" => "790"}]}} = Space.list(client, 123, archived: true)
    end

    test "create/3 posts attrs without a wrapper", %{client: client, stub: stub} do
      Req.Test.expect(stub, fn conn ->
        assert conn.body_params["name"] == "New Space"

        conn
        |> assert_method("POST")
        |> assert_path(["team", "123", "space"])
        |> Req.Test.json(%{"id" => "790", "name" => "New Space"})
      end)

      assert {:ok, %{"id" => "790"}} =
               Space.create(client, 123, %{"name" => "New Space", "multiple_assignees" => true})
    end

    test "get/update/delete round trip", %{client: client, stub: stub} do
      Req.Test.expect(stub, fn conn ->
        conn
        |> assert_method("GET")
        |> assert_path(["space", "790"])
        |> Req.Test.json(%{"id" => "790"})
      end)

      Req.Test.expect(stub, fn conn ->
        assert conn.body_params["name"] == "Renamed"

        conn
        |> assert_method("PUT")
        |> assert_path(["space", "790"])
        |> Req.Test.json(%{"id" => "790", "name" => "Renamed"})
      end)

      Req.Test.expect(stub, fn conn ->
        conn
        |> assert_method("DELETE")
        |> assert_path(["space", "790"])
        |> Req.Test.json(%{})
      end)

      assert {:ok, %{"id" => "790"}} = Space.get(client, 790)
      assert {:ok, %{"name" => "Renamed"}} = Space.update(client, 790, %{name: "Renamed"})
      assert {:ok, %{}} = Space.delete(client, 790)
    end
  end

  describe "Folder" do
    test "list/3 and create/3", %{client: client, stub: stub} do
      Req.Test.expect(stub, fn conn ->
        conn
        |> assert_method("GET")
        |> assert_path(["space", "789", "folder"])
        |> Req.Test.json(%{"folders" => [%{"id" => "457"}]})
      end)

      Req.Test.expect(stub, fn conn ->
        conn
        |> assert_method("POST")
        |> assert_path(["space", "789", "folder"])
        |> Req.Test.json(%{"id" => "460", "name" => "F"})
      end)

      assert {:ok, %{"folders" => [%{"id" => "457"}]}} = Folder.list(client, 789)
      assert {:ok, %{"id" => "460"}} = Folder.create(client, 789, %{name: "F"})
    end

    test "get/update/delete round trip", %{client: client, stub: stub} do
      Req.Test.expect(stub, fn conn ->
        conn |> assert_path(["folder", "457"]) |> Req.Test.json(%{"id" => "457"})
      end)

      Req.Test.expect(stub, fn conn ->
        conn
        |> assert_method("PUT")
        |> assert_path(["folder", "457"])
        |> Req.Test.json(%{"id" => "457", "name" => "New"})
      end)

      Req.Test.expect(stub, fn conn ->
        conn |> assert_method("DELETE") |> assert_path(["folder", "457"]) |> Req.Test.json(%{})
      end)

      assert {:ok, %{"id" => "457"}} = Folder.get(client, 457)
      assert {:ok, %{"name" => "New"}} = Folder.update(client, 457, %{name: "New"})
      assert {:ok, %{}} = Folder.delete(client, 457)
    end
  end

  describe "List" do
    test "list_in_folder/3 and list_in_space/3", %{client: client, stub: stub} do
      Req.Test.expect(stub, fn conn ->
        conn
        |> assert_path(["folder", "456", "list"])
        |> Req.Test.json(%{"lists" => [%{"id" => "124"}]})
      end)

      Req.Test.expect(stub, fn conn ->
        conn
        |> assert_path(["space", "789", "list"])
        |> Req.Test.json(%{"lists" => []})
      end)

      assert {:ok, %{"lists" => [%{"id" => "124"}]}} = List.list_in_folder(client, 456)
      assert {:ok, %{"lists" => []}} = List.list_in_space(client, 789)
    end

    test "create_in_folder/3 and create_in_space/3", %{client: client, stub: stub} do
      Req.Test.expect(stub, fn conn ->
        conn
        |> assert_method("POST")
        |> assert_path(["folder", "456", "list"])
        |> Req.Test.json(%{"id" => "124", "name" => "L"})
      end)

      Req.Test.expect(stub, fn conn ->
        conn
        |> assert_method("POST")
        |> assert_path(["space", "789", "list"])
        |> Req.Test.json(%{"id" => "125", "name" => "L2"})
      end)

      assert {:ok, %{"id" => "124"}} = List.create_in_folder(client, 456, %{name: "L"})
      assert {:ok, %{"id" => "125"}} = List.create_in_space(client, 789, %{name: "L2"})
    end

    test "get/update/delete round trip", %{client: client, stub: stub} do
      Req.Test.expect(stub, fn conn ->
        conn |> assert_path(["list", "124"]) |> Req.Test.json(%{"id" => "124"})
      end)

      Req.Test.expect(stub, fn conn ->
        conn
        |> assert_method("PUT")
        |> assert_path(["list", "124"])
        |> Req.Test.json(%{"id" => "124", "name" => "U"})
      end)

      Req.Test.expect(stub, fn conn ->
        conn |> assert_method("DELETE") |> assert_path(["list", "124"]) |> Req.Test.json(%{})
      end)

      assert {:ok, %{"id" => "124"}} = List.get(client, 124)
      assert {:ok, %{"name" => "U"}} = List.update(client, 124, %{name: "U"})
      assert {:ok, %{}} = List.delete(client, 124)
    end
  end
end

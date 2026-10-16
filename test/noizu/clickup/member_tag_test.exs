defmodule Noizu.ClickUp.MemberTagTest do
  use Noizu.ClickUp.Case, async: true

  alias Noizu.ClickUp.Member
  alias Noizu.ClickUp.Tag

  test "list_task_members/2", %{client: client, stub: stub} do
    Req.Test.expect(stub, fn conn ->
      conn
      |> assert_path(["task", "9hz", "member"])
      |> Req.Test.json(%{"members" => [%{"id" => 183, "username" => "keith"}]})
    end)

    assert {:ok, %{"members" => [%{"id" => 183}]}} = Member.list_task_members(client, "9hz")
  end

  test "list_list_members/2", %{client: client, stub: stub} do
    Req.Test.expect(stub, fn conn ->
      conn
      |> assert_path(["list", "987", "member"])
      |> Req.Test.json(%{"members" => []})
    end)

    assert {:ok, %{"members" => []}} = Member.list_list_members(client, 987)
  end

  test "list_space_tags/2", %{client: client, stub: stub} do
    Req.Test.expect(stub, fn conn ->
      conn
      |> assert_path(["space", "789", "tag"])
      |> Req.Test.json(%{"tags" => [%{"name" => "ops", "tag_fg" => "#000", "tag_bg" => "#fff"}]})
    end)

    assert {:ok, %{"tags" => [%{"name" => "ops"}]}} = Tag.list_space_tags(client, 789)
  end

  test "create_space_tag/3 wraps the tag body", %{client: client, stub: stub} do
    Req.Test.expect(stub, fn conn ->
      assert conn.body_params["tag"]["name"] == "ops"

      conn
      |> assert_method("POST")
      |> assert_path(["space", "789", "tag"])
      |> Req.Test.json(%{})
    end)

    assert {:ok, %{}} =
             Tag.create_space_tag(client, 789, %{name: "ops", tag_fg: "#000", tag_bg: "#fff"})
  end

  test "update_space_tag/4 and delete_space_tag/3 URL-encode the name", %{
    client: client,
    stub: stub
  } do
    Req.Test.expect(stub, fn conn ->
      # Wire path keeps percent-encoding; ClickUp's router decodes "my%20tag" -> "my tag".
      assert conn.path_info == ["space", "789", "tag", "my%20tag"]
      assert conn.body_params["tag"]["name"] == "renamed"

      conn
      |> assert_method("PUT")
      |> Req.Test.json(%{"tag" => %{"name" => "renamed"}})
    end)

    Req.Test.expect(stub, fn conn ->
      conn
      |> assert_method("DELETE")
      |> assert_path(["space", "789", "tag", "my%20tag"])
      |> Req.Test.json(%{})
    end)

    assert {:ok, %{"tag" => %{"name" => "renamed"}}} =
             Tag.update_space_tag(client, 789, "my tag", %{name: "renamed"})

    assert {:ok, %{}} = Tag.delete_space_tag(client, 789, "my tag")
  end

  test "add_to_task/4 and remove_from_task/4", %{client: client, stub: stub} do
    Req.Test.expect(stub, fn conn ->
      assert conn.query_params["custom_task_ids"] == "true"

      conn
      |> assert_method("POST")
      |> assert_path(["task", "9hz", "tag", "urgent"])
      |> Req.Test.json(%{})
    end)

    Req.Test.expect(stub, fn conn ->
      conn
      |> assert_method("DELETE")
      |> assert_path(["task", "9hz", "tag", "urgent"])
      |> Req.Test.json(%{})
    end)

    assert {:ok, %{}} = Tag.add_to_task(client, "9hz", "urgent", custom_task_ids: true)
    assert {:ok, %{}} = Tag.remove_from_task(client, "9hz", "urgent")
  end
end

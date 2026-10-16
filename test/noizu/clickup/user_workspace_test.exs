defmodule Noizu.ClickUp.UserWorkspaceTest do
  use Noizu.ClickUp.Case, async: true

  alias Noizu.ClickUp.User
  alias Noizu.ClickUp.Workspace

  test "get/1 returns the authorized user", %{client: client, stub: stub} do
    Req.Test.expect(stub, fn conn ->
      conn
      |> assert_method("GET")
      |> assert_path(["user"])
      |> assert_token()
      |> Req.Test.json(%{"user" => %{"id" => 183, "username" => "keith"}})
    end)

    assert {:ok, %{"user" => %{"id" => 183, "username" => "keith"}}} = User.get(client)
  end

  test "list_authorized/1 returns teams", %{client: client, stub: stub} do
    Req.Test.expect(stub, fn conn ->
      conn
      |> assert_method("GET")
      |> assert_path(["team"])
      |> Req.Test.json(%{"teams" => [%{"id" => "123", "name" => "Noizu"}]})
    end)

    assert {:ok, %{"teams" => [%{"id" => "123"}]}} = Workspace.list_authorized(client)
  end

  test "propagates ClickUp error bodies", %{client: client, stub: stub} do
    Req.Test.expect(stub, fn conn ->
      respond(conn, 401, %{"err" => "Token invalid", "ECODE" => "OAUTH_019"})
    end)

    assert {:error, %Noizu.ClickUp.Error{status: 401, code: "OAUTH_019"}} =
             Workspace.list_authorized(client)
  end
end

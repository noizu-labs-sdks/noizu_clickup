defmodule Noizu.ClickUp.PathEncodingTest do
  use Noizu.ClickUp.Case, async: true

  alias Noizu.ClickUp.Request

  describe "T-005 — resource ids are encoded as single path segments" do
    test "an id with traversal and query material stays one opaque segment", %{
      client: client,
      stub: stub
    } do
      malicious = "1/../../team?x=1"

      Req.Test.expect(stub, fn conn ->
        assert conn.path_info == ["task", "1%2F..%2F..%2Fteam%3Fx%3D1"]
        refute conn.query_params["x"]

        conn |> assert_method("GET") |> Req.Test.json(%{"id" => malicious})
      end)

      assert {:ok, _} = Noizu.ClickUp.Task.get(client, malicious)
    end

    test "segment/1 percent-encodes separators, keeps unreserved characters" do
      assert Request.segment("1/../../team?x=1") == "1%2F..%2F..%2Fteam%3Fx%3D1"
      assert Request.segment("abcDEF-9_z.~") == "abcDEF-9_z.~"
      assert Request.segment("a b&c=d#e%f") == "a%20b%26c%3Dd%23e%25f"
    end

    test "segment/1 accepts integers" do
      assert Request.segment(867_5309) == "8675309"
    end

    test "every resource call encodes its ids (folder traversal via list id)", %{
      client: client,
      stub: stub
    } do
      evil = "../team"

      Req.Test.expect(stub, fn conn ->
        assert conn.path_info == ["list", "..%2Fteam"]

        Req.Test.json(conn, %{"id" => evil})
      end)

      assert {:ok, _} = Noizu.ClickUp.List.get(client, evil)
    end
  end
end

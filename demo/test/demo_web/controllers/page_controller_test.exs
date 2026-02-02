defmodule DemoWeb.PageControllerTest do
  use DemoWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert html_response(conn, 200) =~
             "Visual workflow editor with drag-and-drop nodes, pan/zoom, and database persistence"
  end
end

defmodule ExFlowGraphWeb.PageController do
  use ExFlowGraphWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

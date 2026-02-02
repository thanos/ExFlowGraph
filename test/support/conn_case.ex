defmodule ExFlowGraphWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and test web components.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use ExFlowGraphWeb, :verified_routes

      import ExFlowGraphWeb.ConnCase
      import Phoenix.ConnTest
      import Plug.Conn

      # The default endpoint for testing
      @endpoint ExFlowGraphWeb.Endpoint
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end

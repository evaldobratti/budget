defmodule BudgetWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use BudgetWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """
  alias Budget.Users

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint BudgetWeb.Endpoint

      use BudgetWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import BudgetWeb.ConnCase
      import Budget.Simplifiers
      import Budget.TimeHelper
    end
  end

  setup tags do
    Budget.DataCase.setup_sandbox(tags)

    user = Users.get_user_by_email!("mocked@provider.com")

    conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.put_session("user_id", user.id)
      |> Plug.Conn.put_session("active_profile_id", Enum.at(user.profiles, 0).id)

    {:ok, conn: conn}
  end
end

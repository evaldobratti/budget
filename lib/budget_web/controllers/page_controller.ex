defmodule BudgetWeb.PageController do
  use BudgetWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

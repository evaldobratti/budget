defmodule BudgetWeb.ImportLive.Result do
  use BudgetWeb, :live_view

  def mount(%{"result" => result}, _session, socket) do
    {
      :ok,
      socket
      |> assign(result: result)
    }
  end



  
  
end

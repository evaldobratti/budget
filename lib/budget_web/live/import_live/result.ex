defmodule BudgetWeb.ImportLive.Result do
  use BudgetWeb, :live_view

  alias Budget.Importations.Worker

  def mount(%{"result" => digits}, _session, socket) do
    pid = 
      digits
      |> Budget.Importations.find_process()

    if connected?(socket) do
      IO.inspect("conectei")
      Worker.checkin(pid)
    end

    result = Worker.result(pid)

    
    {
      :ok,
      socket
      |> assign(digits: digits)
      |> assign(pid: pid)
      |> assign(result: result)
    }
  end



  
  
end

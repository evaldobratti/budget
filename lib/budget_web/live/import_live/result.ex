defmodule BudgetWeb.ImportLive.Result do
  use BudgetWeb, :live_view

  alias Budget.Transactions
  alias Budget.Importations.Worker

  def mount(%{"result" => digits}, _session, socket) do
    pid = 
      digits
      |> Budget.Importations.find_process()

    # if connected?(socket) do
    #   Worker.checkin(pid)
    # end

    result = Worker.result(pid)

    {
      :ok,
      socket
      |> assign(digits: digits)
      |> assign(pid: pid)
      |> assign(result: result)
      |> assign(changes: [])
      |> assign(changes_applied: result)
      |> assign(categories: Transactions.list_categories())
    }
  end


  def handle_event("validate-" <> ix, payload, socket) do
    socket
    |> update(:changes, fn changes -> 
      change =           
        payload 
        |> Map.delete("_target")
        |> Enum.map(fn {key, value} -> {String.to_existing_atom(key), value} end) 
        |> Enum.into(%{}) 
        |> Map.put(:ix, String.to_integer(ix)) 

      [{:change, change} | changes] 
    end)
    |> apply_changes()
  end

  def handle_event("delete-" <> ix, _payload, socket) do
    socket
    |> update(:changes, fn changes -> [{:delete, String.to_integer(ix)} | changes] end)
    |> apply_changes()
  end

  defp apply_changes(socket) do
    changes_applied =
      socket.assigns.changes
      |> Enum.reverse()
      |> Enum.reduce(socket.assigns.result, fn 
        {:change, change}, acc ->
          transactions = 
            Enum.map(acc.transactions, fn original ->
              if original.ix == change.ix do
                Map.merge(original, change)
              else
                original
              end
            end)

          Map.put(acc, :transactions, transactions)

        {:delete, ix}, acc ->
          transactions =
            Enum.filter(acc.transactions, & &1.ix !== ix)

          Map.put(acc, :transactions, transactions)
      end)

    {
      :noreply,
      socket
      |> assign(changes_applied: changes_applied)
    }
  end

  
  
end

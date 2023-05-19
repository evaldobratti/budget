defmodule Budget.Importations.Worker do
  use GenServer, restart: :transient

  alias Budget.Hinter
  alias Budget.Importations.CreditCard.NuBank

  def name(digits) do
    {:via, Registry, {Buget.Importer.Registry, digits}}
  end

  def whereis(digits) do
    case Registry.lookup(Buget.Importer.Registry, digits) do
      [] -> nil
      [{pid, _}] -> pid
    end
  end

  def start_link(%{name: name} = args) do
    GenServer.start_link(
      __MODULE__, 
      args, 
      name: name
    )
  end

  def checkin(pid) do
    Process.link(pid)
    GenServer.cast(pid, :checked)
  end

  def result(pid) do
    GenServer.call(pid, :result)
  end

  @impl true
  def init(%{file: file}) do
    send(self(), :process)
    # Process.send_after(self(), :check_alive, 200)

    {:ok, %{file: file, checked: false, result: :processing}}
  end

  @impl true
  def handle_info(:process, %{file: file} = state) do
    result = NuBank.import(file)

    hinted_transactions =
      result.transactions
      |> Enum.map(fn 
        %{type: :transaction} = transaction ->
          hint = 
            case Hinter.hint_description(transaction.description) do
              [hint | _] -> hint.suggestion
              [] -> transaction.description
            end
          category = Hinter.hint_category(transaction.description, nil)

          transaction
          |> Map.put(:original_description, transaction.description)
          |> Map.put(:description, hint)
          |> Map.put(:category_id, Map.get(category || %{}, :id))

        other -> other
      end)

    result = Map.put(result, :transactions, hinted_transactions)

    {:noreply, %{state | result: result}}
  end

  @impl true
  def handle_info(:check_alive, %{checked: true} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(:check_alive, state) do
    {:stop, :none_connected, state}
  end

  @impl true
  def handle_info({:EXIT, _live_view, {:shutdown, :closed}}, state) do
    {:stop, :shutdown, state}
  end

  @impl true
  def handle_cast(:checked, state) do
    Process.flag(:trap_exit, true)
    {:noreply, %{state | checked: true}}
  end

  @impl true
  def handle_call(:result, _pid, state) do
    {:reply, state.result, state}
  end

end

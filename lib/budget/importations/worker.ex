defmodule Budget.Importations.Worker do
  use GenServer, restart: :transient

  alias Budget.Importations
  alias Budget.Hinter
  alias Budget.Importations.CreditCard.NuBank

  def name(key) do
    {:via, Registry, {Buget.Importer.Registry, key}}
  end

  def whereis(key) do
    case Registry.lookup(Buget.Importer.Registry, key) do
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
    GenServer.cast(pid, {:checked, self()})
  end

  def result(pid) do
    GenServer.call(pid, :result)
  end

  def import_file_data(pid) do
    GenServer.call(pid, :import_file_data)
  end

  @impl true
  def init(%{file: file}) do
    send(self(), :process)
    Process.send_after(self(), :check_alive, 20000)

    {:ok, %{file: file, checked: false, live_view: nil, result: :processing}}
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

          transaction = %{
            "type" => :transaction,
            "ix" => transaction.ix,
            "date" => transaction.date,
            "value" => transaction.value,
            "originator" => "regular",
            "regular" => %{
              "category_id" => Map.get(category || %{}, :id),
              "description" => hint,
              "original_description" => transaction.description
            },
            "transfer" => %{
              "other_account_id" => nil
            }
          }

          hash = build_hash(transaction)

          conflict = Importations.has_conflict?(hash)

          transaction
          |> Map.put("conflict", conflict)
          |> Map.put("hash", hash)

        other ->
          other
      end)

    result = Map.put(result, :transactions, hinted_transactions)

    if state.live_view do
      send(state.live_view, {:finished, result})
    end

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
  def handle_info({:EXIT, _live_view, {:shutdown, _}}, state) do
    {:stop, :shutdown, state}
  end

  @impl true
  def handle_info({:EXIT, _live_view, :shutdown}, state) do
    {:stop, :shutdown, state}
  end

  @impl true
  def handle_info({:EXIT, _live_view, _}, state) do
    {:stop, :shutdown, state}
  end

  @impl true
  def handle_cast({:checked, live_view}, state) do
    Process.flag(:trap_exit, true)

    if state.result != :processing do
      send(live_view, {:finished, state.result})
    end

    {:noreply, %{state | checked: true, live_view: live_view}}
  end

  @impl true
  def handle_call(:result, _pid, state) do
    {:reply, state.result, state}
  end

  @impl true
  def handle_call(:import_file_data, _pid, %{file: file, result: result} = state) do
    hashes =
      result.transactions
      |> Enum.filter(&(&1["type"] == :transaction))
      |> Enum.map(&build_hash/1)

    {:reply, %{name: file, hashes: hashes}, state}
  end

  defp build_hash(%{
         "ix" => ix,
         "date" => date,
         "value" => value,
         "regular" => %{
           "original_description" => description
         }
       }) do
    "#{ix}-#{date}-#{value}-#{description}"
  end
end

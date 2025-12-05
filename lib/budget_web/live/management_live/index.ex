defmodule BudgetWeb.ManagementLive.Index do
  use BudgetWeb, :live_view

  alias Budget.Transactions

  @impl true
  def mount(_params, _session, socket) do
    %{id: profile_id} = socket.assigns.active_profile

    {
      :ok,
      socket
      |> assign(categories: Transactions.list_categories_arranged())
      |> assign_async(:averages, fn ->
        Budget.Repo.put_profile_id(profile_id)

        {:ok, %{averages: build_average()}}
      end)
    }
  end

  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign(url_params: params)

    {:noreply, socket}
    
  end

  def build_average() do
    categories = Transactions.list_categories_arranged()

    categories_ids =
      categories
      |> Enum.map(fn
        {parent, children} -> [parent.id | Enum.map(children, &elem(&1, 0).id)]
      end)

    six_months_ago = Timex.now() |> Timex.beginning_of_month() |> Timex.shift(months: -6)

    collect_averages(categories_ids, six_months_ago)
  end

  def collect_averages(categories_ids, date) do
    if Date.after?(date, Date.utc_today()) do
      %{}
    else
      start_month = date
      end_month = Timex.end_of_month(date)

      averages =
        categories_ids
        |> Enum.map(
          &{&1, Transactions.transactions_in_period(start_month, end_month, category_ids: &1)}
        )
        |> Enum.map(fn {ids, transactions} ->
          {Enum.at(ids, 0),
           transactions
           |> Enum.map(& &1.value)
           |> Enum.reduce(Decimal.new(0), &Decimal.add/2)}
        end)
        |> Enum.into(%{})

      %{}
      |> Map.put(start_month, averages)
      |> Map.merge(collect_averages(categories_ids, Timex.shift(date, months: 1)))
    end
  end

  def available_months(averages) do
    averages |> Map.keys() |> Enum.uniq()
  end
end

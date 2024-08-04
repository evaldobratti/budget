defmodule BudgetWeb.ChartLive.Index do
  alias Budget.Transactions
  use BudgetWeb, :live_view

  alias Budget.Reports
  alias Phoenix.HTML.Form

  @colors [
    "rgba(255, 99, 132, 1)",
    "rgba(54, 162, 235, 1)", 
    "rgba(255, 206, 86, 1)",
    "rgba(75, 192, 192, 1)",
    "rgba(153, 102, 255, 1)", 
    "rgba(255, 159, 64, 1)",
    "rgba(199, 199, 199, 1)", 
    "rgba(83, 102, 255, 1)",
    "rgba(255, 102, 204, 1)", 
    "rgba(102, 255, 178, 1)", 
    "rgba(204, 255, 51, 1)",
    "rgba(255, 102, 0, 1)",
    "rgba(102, 255, 102, 1)", 
    "rgba(102, 178, 255, 1)", 
    "rgba(178, 102, 255, 1)", 
    "rgba(255, 153, 153, 1)", 
    "rgba(153, 204, 255, 1)", 
    "rgba(255, 255, 153, 1)", 
    "rgba(153, 153, 255, 1)", 
    "rgba(102, 102, 255, 1)", 
    "rgba(204, 204, 255, 1)", 
    "rgba(255, 255, 204, 1)", 
    "rgba(204, 255, 204, 1)", 
    "rgba(255, 204, 204, 1)", 
    "rgba(255, 102, 178, 1)", 
    "rgba(255, 204, 102, 1)", 
    "rgba(102, 102, 153, 1)", 
    "rgba(255, 229, 204, 1)", 
    "rgba(204, 204, 255, 1)", 
    "rgba(255, 153, 102, 1)", 
  ]

  @impl true
  def mount(_params, _session, socket) do
    categories = Transactions.list_categories() |> IO.inspect()

    {
      :ok,
      socket
      |> assign(
        colors: categories
        |> Enum.with_index(fn c, ix ->
          {"#{c.id} - #{c.name}", Enum.at(@colors, ix)}
        end)
        |> Enum.into(%{})
      )
      |> assign(
        dates: [
          Timex.today() |> Timex.beginning_of_year(), 
          Timex.today() |> Timex.end_of_year()
        ]
      )
      |> update_reports()
    }
  end

  def update_reports(socket) do
    [date_start, date_end] = socket.assigns.dates    

    params = %{
      date_start: date_start, 
      date_end: date_end
    }

    socket
    |> assign(expenses: Reports.expenses(params))
    |> assign(incomes: Reports.incomes(params))
  end

  @impl true
  def handle_info({:dates, dates}, socket) do
    {
      :noreply,
      socket
      |> assign(dates: dates)
      |> update_reports()
    }
  end
end

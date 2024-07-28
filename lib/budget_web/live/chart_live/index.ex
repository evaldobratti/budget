defmodule BudgetWeb.ChartLive.Index do
  use BudgetWeb, :live_view

  alias Budget.Reports
  alias Phoenix.HTML.Form

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
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

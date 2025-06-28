defmodule BudgetWeb.ChartLive.Index do
  alias Budget.Transactions
  use BudgetWeb, :live_view

  alias Budget.Reports

  @date_format "{YYYY}-{0M}-{0D}"

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
    "rgba(255, 153, 102, 1)"
  ]

  @impl true
  def mount(_params, _session, socket) do
    categories = Transactions.list_categories()

    {
      :ok,
      socket
      |> assign(categories: Transactions.list_categories_arranged())
      |> assign(accounts: Transactions.list_accounts())
      |> assign(accounts_selected_ids: [])
      |> assign(category_selected_ids: [])
      |> assign(
        colors:
          categories
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
    account_ids = socket.assigns.accounts_selected_ids
    category_ids = socket.assigns.category_selected_ids

    params = [
      account_ids: account_ids,
      category_ids: category_ids
    ]

    socket
    |> assign(expenses: Reports.expenses(date_start, date_end, params))
    |> assign(incomes: Reports.incomes(date_start, date_end, params))
  end

  @impl true
  def handle_info({:accounts_selected_ids, ids}, socket) do
    {
      :noreply,
      socket
      |> assign(accounts_selected_ids: ids)
      |> update_reports()
    }
  end

  def handle_info({:category_selected_ids, ids}, socket) do
    {
      :noreply,
      socket
      |> assign(category_selected_ids: ids)
      |> update_reports()
    }
  end

  def handle_info({:dates, dates}, socket) do
    {
      :noreply,
      socket
      |> assign(dates: dates)
      |> update_reports()
    }
  end

  def format_dates(month) do
    Jason.encode!([
      Timex.beginning_of_month(month) |> Timex.format!(@date_format),
      Timex.end_of_month(month) |> Timex.format!(@date_format)
    ])
  end
end

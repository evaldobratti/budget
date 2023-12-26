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
        form:
          to_form(%{
            "date_start" => Timex.today() |> Timex.beginning_of_year() |> Date.to_iso8601(),
            "date_end" => Timex.today() |> Timex.end_of_year() |> Date.to_iso8601()
          })
      )
      |> update_reports()
    }
  end

  @impl true
  def handle_event("validate", form, socket) do
    {
      :noreply,
      socket
      |> assign(form: to_form(form))
      |> update_reports()
    }
  end

  def update_reports(socket) do
    date_start = Form.input_value(socket.assigns.form, "date_start") |> Date.from_iso8601!()
    date_end = Form.input_value(socket.assigns.form, "date_end") |> Date.from_iso8601!()

    socket
    |> assign(expenses: Reports.expenses(%{date_start: date_start, date_end: date_end}))
    |> assign(incomes: Reports.incomes(%{date_start: date_start, date_end: date_end}))
  end
end

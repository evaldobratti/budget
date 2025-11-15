defmodule BudgetWeb.Transactions.DateRangePicker do
  use BudgetWeb, :live_component

  def render(assigns) do
    ~H"""
      <div class="mx-auto">
        <% dates_form = to_form(%{
          "date_start" => Timex.format!(Enum.at(@dates, 0), "{YYYY}-{0M}-{0D}"),
          "date_end" =>Timex.format!(Enum.at(@dates, 1), "{YYYY}-{0M}-{0D}")
        }) %>
        <.form
          id="dates-switch"
          for={dates_form}
          as={:dates}
          phx-change="update-dates"
          phx-target={@myself}
        >
          <div class="flex items-center gap-2 items-center">
            <button class="btn btn-primary" phx-click="month-previous" type="button" phx-target={@myself}><%= "<<" %></button>
            <.input field={dates_form[:date_start]} type="date" margin={false} />
            <div class="d-inline px-1">to</div>
            <.input field={dates_form[:date_end]} type="date" margin={false}/>
            <button class="btn btn-primary" phx-click="month-next" type="button" phx-target={@myself}><%= ">>" %></button>
          </div>
        </.form>
      </div>
    """
  end

  def handle_event("month-previous", _params, socket) do
    dates = shift_dates(socket, -1)

    send(self(), {:dates, dates})

    {
      :noreply,
      socket
    }
  end

  def handle_event("month-next", _params, socket) do
    dates = shift_dates(socket, 1)

    send(self(), {:dates, dates})

    {
      :noreply,
      socket
    }
  end

  def handle_event("update-dates", %{"date_start" => date_start, "date_end" => date_end}, socket) do
    {:ok, date_start} = Timex.parse(date_start, "{YYYY}-{0M}-{0D}")
    {:ok, date_end} = Timex.parse(date_end, "{YYYY}-{0M}-{0D}")

    date_end =
      if Timex.after?(date_start, date_end) do
        date_start
      else
        date_end
      end

    send(self(), {:dates, [date_start, date_end]})

    {
      :noreply,
      socket
    }
  end

  defp shift_dates(socket, direction) do
    [date_start, date_end] = socket.assigns.dates

    is_first_day = Timex.equal?(date_start, date_start |> Timex.beginning_of_month())

    is_last_day =
      Timex.equal?(date_end, date_end |> Timex.end_of_month() |> Timex.beginning_of_day())

    if is_first_day and is_last_day do
      date_start =
        date_start
        |> Timex.shift(months: direction)
        |> Timex.beginning_of_month()

      [
        date_start,
        Timex.end_of_month(date_start)
      ]
    else
      socket.assigns.dates
      |> Enum.map(&Timex.shift(&1, months: direction))
    end
  end
  
end

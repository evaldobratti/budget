defmodule BudgetWeb.BudgetLive.Index do
  use BudgetWeb, :live_view

  alias Budget.Entries

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(accounts_selected_ids: [])
      |> assign(dates: [Timex.beginning_of_month(Timex.today()), Timex.end_of_month(Timex.today)])
      |> assign(modal_new_entry: false)
      |> assign(modal_edit_entry: nil)
      |> assign(balances: [0, 0])
      |> reload_entries()
    }
  end

  @impl true
  def handle_params(params, _url, socket) do
    {
      :noreply,
      socket
      |> apply_action(socket.assigns.live_action, params)
      |> apply_return_from(Map.get(params, "from", ""))
    }
  end

  def apply_action(socket, :new_account, _params) do
    socket
    |> assign(account: %Entries.Account{})
  end

  def apply_action(socket, :edit_account, %{"id" => id}) do
    socket
    |> assign(account: Entries.get_account!(id))
  end

  def apply_action(socket, _, _) do
    socket
  end

  def apply_return_from(socket, from) when from in ["account", "entry"] do 
    reload_entries(socket)
  end

  def apply_return_from(socket, _), do: socket

  def handle_event("month-previous", _params, socket) do
    [date_start | _] = socket.assigns.dates

    date_start = 
      date_start
      |> Timex.shift(months: -1)
      |> Timex.beginning_of_month()

    dates = [
      date_start, 
      Timex.end_of_month(date_start)
    ]

    {
      :noreply,
      socket
      |> assign(dates: dates)
      |> put_flash(:info, Date.to_iso8601(date_start))
      |> reload_entries()
    }
  end

  def handle_event("month-next", _params, socket) do
    [date_start | _] = socket.assigns.dates

    date_start = 
      date_start
      |> Timex.shift(months: 1)
      |> Timex.beginning_of_month()

    dates = [
      date_start, 
      Timex.end_of_month(date_start)
    ]

    {
      :noreply,
      socket
      |> assign(dates: dates)
      |> reload_entries()
    }
  end

  def handle_event("toggle-account", %{"account-id" => account_id}, socket) do
    {account_id, _} = Integer.parse(account_id)

    accounts_selected_ids = 
      if account_id in socket.assigns.accounts_selected_ids do
        List.delete(socket.assigns.accounts_selected_ids, account_id)
      else
        [account_id | socket.assigns.accounts_selected_ids ]
      end

    {
      :noreply,
      socket
      |> assign(accounts_selected_ids: accounts_selected_ids)
      |> reload_entries()
    }
  end

  def handle_event("update-dates", %{"date-start" => date_start, "date-end" => date_end}, socket) do
    {:ok, date_start} = Timex.parse(date_start, "{YYYY}-{0M}-{0D}")
    {:ok, date_end} = Timex.parse(date_end, "{YYYY}-{0M}-{0D}")

    date_end = 
      if Timex.after?(date_start, date_end) do
        date_start
      else
        date_end
      end

    {
      :noreply,
      socket
      |> assign(dates: [date_start, date_end])
      |> reload_entries()
    }
  end

  defp reload_entries(socket) do
    accounts_ids = socket.assigns.accounts_selected_ids
    [date_start, date_end] = socket.assigns.dates

    previous_balance = Entries.balance_at(accounts_ids, Timex.shift(date_start, days: -1))
    next_balance = Entries.balance_at(accounts_ids, date_end)

    entries = Entries.entries_in_period(accounts_ids, date_start, date_end)

    socket
    |> assign(accounts: Entries.list_accounts())
    |> assign(entries: Enum.sort(entries, &Timex.before?(&1.date, &2.date)))
    |> assign(balances: [previous_balance, next_balance])
  end

  def accounts_selected(accounts_ids, accounts) when is_list(accounts_ids) do
    accounts
    |> Enum.filter(& &1.id in accounts_ids)
  end

  def accounts_selected(_par1, _par2) do
    []
  end

  
end

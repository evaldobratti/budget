defmodule BudgetWeb.BudgetLive.Index do
  use BudgetWeb, :live_view

  alias Budget.Entries

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(accounts: Entries.list_accounts())
      |> assign(modal_account_action: nil)
      |> assign(accounts_selected_ids: [])
      |> assign(dates: [Timex.beginning_of_month(Timex.today()), Timex.end_of_month(Timex.today)])
      |> assign(modal_new_entry: false)
      |> assign(modal_edit_entry: nil)
      |> assign(balances: [0, 0])
      |> reload_entries()
    }
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  def handle_event("account_new", _params, socket) do
    {
      :noreply,
      socket
      |> assign(modal_account_action: :new)
      |> assign(account: %Entries.Account{})
    }
  end

  def handle_event("account_edit", %{"account-id" => account_id}, socket) do
    {
      :noreply,
      socket
      |> assign(modal_account_action: :edit)
      |> assign(account: Entries.get_account!(account_id))
    }
  end

  def handle_event("close_account_modal", _params, socket) do
    {
      :noreply,
      assign(socket, modal_account_action: nil)
    }
  end

  def handle_event("close_new_entry_modal", _params, socket) do
    {
      :noreply,
      assign(socket, modal_new_entry: false)
    }
  end

  def handle_event("close_edit_entry_modal", _params, socket) do
    {
      :noreply,
      assign(socket, modal_edit_entry: nil)
    }
  end

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

  def handle_event("modal-new-entry", _, socket) do
    {
      :noreply, 
      socket
      |> assign(modal_new_entry: true)
    }
  end

  def handle_event("entry-edit", %{"entry-id" => entry_id}, socket) do
    {
      :noreply,
      socket
      |> assign(modal_edit_entry: Entries.get_entry!(entry_id))
    }
  end

  defp reload_entries(socket) do
    accounts_ids = socket.assigns.accounts_selected_ids
    [start_date, end_date] = socket.assigns.dates

    previous_balance = Entries.balance_at(accounts_ids, start_date)
    next_balance = Entries.balance_at(accounts_ids, Timex.shift(end_date, days: 1))

    socket
    |> assign(entries: Entries.list_entriess_from_accounts(accounts_ids, start_date, end_date))
    |> assign(balances: [previous_balance, next_balance])
  end

  @impl true
  def handle_info([{action, _account}], socket) when action in [:account_created, :account_updated] do
    {
      :noreply, 
      socket
      |> assign(accounts: Entries.list_accounts())
      |> assign(modal_account_action: nil)
      |> reload_entries()
    }
  end

  @impl true
  def handle_info([{action, _account}], socket) when action in [:entry_created, :entry_updated] do
    {
      :noreply, 
      socket
      |> assign(modal_new_entry: false)
      |> assign(modal_edit_entry: nil)
      |> reload_entries()
    }
  end

  def accounts_selected(accounts_ids, accounts) when is_list(accounts_ids) do
    accounts
    |> Enum.filter(& &1.id in accounts_ids)
  end

  def accounts_selected(_par1, _par2) do
    []
  end

  
end

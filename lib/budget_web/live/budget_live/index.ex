defmodule BudgetWeb.BudgetLive.Index do
  use BudgetWeb, :live_view

  alias Phoenix.LiveView.JS

  alias Budget.Entries
  alias Budget.Entries.Entry

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(accounts_selected_ids: [])
      |> assign(
        dates: [Timex.beginning_of_month(Timex.today()), Timex.end_of_month(Timex.today())]
      )
      |> assign(confirm_delete: nil)
      |> assign(balances: [0, 0])
      |> reload_entries()
    }
  end

  @impl true
  def handle_params(params, _url, socket) do
    if Map.get(params, "entry-add-new") do
      Process.send_after(self(), :add_new_entry, 200)
    end

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

  def apply_action(socket, :new_category, _params) do
    socket
    |> assign(category: %Entries.Category{})
  end

  def apply_action(socket, :edit_category, %{"id" => id}) do
    socket
    |> assign(category: Entries.get_category!(id))
  end

  def apply_action(socket, :new_category_child, %{"id" => id}) do
    socket
    |> assign(category: Entries.get_category!(id))
  end

  def apply_action(socket, :edit_entry, %{"id" => id}) do
    entry =
      case id do
        "recurrency" <> _ ->
          Entries.encarnate_transient_entry(id)

        _ ->
          Entries.get_entry!(id)
      end

    socket
    |> assign(edit_entry: entry)
  end

  def apply_action(socket, :delete_entry, %{"id" => id}) do
    delete_state = Entries.delete_entry_state(id)

    socket
    |> assign(confirm_delete: %{entry_id: id, delete_state: delete_state})
  end

  def apply_action(socket, _, _) do
    socket
  end

  def apply_return_from(socket, from) when from in ["account", "entry", "delete", "category"] do
    reload_entries(socket)
  end

  def apply_return_from(socket, _), do: socket

  @impl true
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
        [account_id | socket.assigns.accounts_selected_ids]
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

  def handle_event("entry-delete", %{"delete-mode" => delete_mode}, socket) do
    entry_id = socket.assigns.confirm_delete.entry_id

    socket =
      case Entries.delete_entry(entry_id, delete_mode) do
        {:ok, _} ->
          socket
          |> put_flash(:info, "Entry successfully deleted!")
          |> push_patch(to: Routes.budget_index_path(socket, :index, from: "delete"))

        _ ->
          socket
          |> put_flash(:error, "An error has occurred!")
      end

    {:noreply, socket}
  end

  def handle_event("reorder", %{"newIndex" => same, "oldIndex" => same}, socket) do
    {:noreply, socket}
  end

  def handle_event("reorder", %{"newIndex" => new_index, "oldIndex" => old_index}, socket) do
    case Entries.update_order(old_index, new_index, socket.assigns.entries) do
      {:ok, _} ->
        {
          :noreply,
          socket
          |> reload_entries()
        }

      _ ->
        {
          :noreply,
          socket
          |> put_flash(:error, "Something went wrong when reordering.")
        }
    end
  end

  defp reload_entries(socket) do
    accounts_ids = socket.assigns.accounts_selected_ids
    [date_start, date_end] = socket.assigns.dates

    previous_balance = Entries.balance_at(accounts_ids, Timex.shift(date_start, days: -1))
    next_balance = Entries.balance_at(accounts_ids, date_end)

    entries = Entries.entries_in_period(accounts_ids, date_start, date_end)

    socket
    |> assign(categories: Entries.list_categories_arranged())
    |> assign(accounts: Entries.list_accounts())
    |> assign(entries: entries)
    |> assign(balances: [previous_balance, next_balance])
  end

  def accounts_selected(accounts_ids, accounts) when is_list(accounts_ids) do
    accounts
    |> Enum.filter(&(&1.id in accounts_ids))
  end

  def accounts_selected(_par1, _par2) do
    []
  end

  def render_categories([], _socket), do: nil

  def render_categories(categories, socket) do
    assigns = %{categories: categories, socket: socket}

    ~H"""
    <%= for {category, children} <- @categories do %>
      <div class="d-flex mt-2">
        <div>
          <%= if length(category.path) > 0, do: "└ " %><%=category.name %>
        </div>
        <div class="ml-auto">
          <%= live_patch "Edit", to: Routes.budget_index_path(@socket, :edit_category, category.id) %>
          <%= live_patch "+", to: Routes.budget_index_path(@socket, :new_category_child, category), class: "btn btn-sm btn-primary" %>
        </div>
      </div>
      <div class="pl-1 ml-1" style="border-left: solid 1px">
        <%= render_categories(children, @socket) %>
      </div>
    <% end %>
    """
  end

  @impl true
  def handle_info(:add_new_entry, socket) do
    {:noreply, socket |> push_patch(to: Routes.budget_index_path(socket, :new_entry))}
  end

  def description(entry) do
    case Entries.originator(entry) do
      %Entries.Originator.Regular{} = regular ->
        regular.description

      %Entries.Originator.Transfer{} ->
        other_part = Entries.get_counter_part(entry)

        if entry.value |> Decimal.negative?() do
          "Transfer to '#{other_part.account.name}'"
        else
          "Transfer from '#{entry.account.name}'"
        end
    end
  end
end

defmodule BudgetWeb.BudgetLive.Index do
  alias Budget.Transactions.Category
  use BudgetWeb, :live_view

  alias Phoenix.LiveView.JS

  alias Budget.Transactions
  alias Budget.Transactions.Transaction

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(accounts_selected_ids: [])
      |> assign(category_selected_ids: [])
      |> assign(
        dates: [Timex.beginning_of_month(Timex.today()), Timex.end_of_month(Timex.today())]
      )
      |> assign(confirm_delete: nil)
      |> assign(balances: [0, 0])
      |> assign(new_transaction_payload: %Transaction{date: Timex.today()})
      |> assign(previous_balance: true)
      |> assign(partial_balance: false)
      |> reload_transactions()
    }
  end

  @impl true
  def handle_params(params, _url, socket) do
    {
      :noreply,
      socket
      |> apply_action(socket.assigns.live_action, params)
      |> apply_return_from(Map.get(params, "from", ""), params)
    }
  end

  def apply_action(socket, :new_account, _params) do
    socket
    |> assign(account: %Transactions.Account{})
  end

  def apply_action(socket, :edit_account, %{"id" => id}) do
    socket
    |> assign(account: Transactions.get_account!(id))
  end

  def apply_action(socket, :new_category, _params) do
    socket
    |> assign(category: %Transactions.Category{})
  end

  def apply_action(socket, :edit_category, %{"id" => id}) do
    socket
    |> assign(category: Transactions.get_category!(id))
  end

  def apply_action(socket, :new_category_child, %{"id" => id}) do
    socket
    |> assign(category: Transactions.get_category!(id))
  end

  def apply_action(socket, :edit_transaction, %{"id" => id}) do
    transaction =
      case id do
        "recurrency" <> _ ->
          Transactions.encarnate_transient_transaction(id)

        _ ->
          Transactions.get_transaction!(id)
      end

    socket
    |> assign(edit_transaction: transaction)
  end

  def apply_action(socket, :delete_transaction, %{"id" => id}) do
    delete_state = Transactions.delete_transaction_state(id)

    socket
    |> assign(confirm_delete: %{transaction_id: id, delete_state: delete_state})
  end

  def apply_action(socket, _, _) do
    socket
  end

  def apply_return_from(socket, "transaction", params) do
    if Map.get(params, "transaction-add-new") do
      Process.send_after(self(), :add_new_transaction, 200)

      socket
      |> update(:new_transaction_payload, &%{&1 | date: Map.get(params, "date")})
      |> update(:new_transaction_payload, &%{&1 | account_id: Map.get(params, "account_id")})
    else
      socket
    end
    |> reload_transactions()
  end

  def apply_return_from(socket, from, _params)
      when from in ["account", "delete", "category"] do
    reload_transactions(socket)
  end

  def apply_return_from(socket, _, _), do: socket

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

  @impl true
  def handle_event("month-previous", _params, socket) do
    dates = shift_dates(socket, -1)

    {
      :noreply,
      socket
      |> assign(dates: dates)
      |> reload_transactions()
    }
  end

  def handle_event("month-next", _params, socket) do
    dates = shift_dates(socket, 1)

    {
      :noreply,
      socket
      |> assign(dates: dates)
      |> reload_transactions()
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
      |> reload_transactions()
    }
  end

  def handle_event("toggle-previous-balance", _params, socket) do
    previous_balance = not socket.assigns.previous_balance

    {
      :noreply,
      socket
      |> assign(previous_balance: previous_balance)
      |> reload_transactions()
    }
  end

  def handle_event("toggle-partial-balance", _params, socket) do
    partial_balance = not socket.assigns.partial_balance

    {
      :noreply,
      socket
      |> assign(partial_balance: partial_balance)
      |> reload_transactions()
    }
  end

  def handle_event("toggle-category", %{"category-id" => category_id} = params, socket) do
    {category_id, _} = Integer.parse(category_id)

    category_ids =
      socket.assigns.categories
      |> Category.find_in_tree(category_id)
      |> Category.get_subtree_ids()

    category_selected_ids =
      if Map.get(params, "value") == "on" do
        Enum.concat(category_ids, socket.assigns.category_selected_ids)
      else
        Enum.filter(socket.assigns.category_selected_ids, &(&1 not in category_ids))
      end
      |> Enum.uniq()

    {
      :noreply,
      socket
      |> assign(category_selected_ids: category_selected_ids)
      |> reload_transactions()
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

    {
      :noreply,
      socket
      |> assign(dates: [date_start, date_end])
      |> reload_transactions()
    }
  end

  def handle_event("transaction-delete", %{"delete-mode" => delete_mode}, socket) do
    transaction_id = socket.assigns.confirm_delete.transaction_id

    socket =
      case Transactions.delete_transaction(transaction_id, delete_mode) do
        {:ok, _} ->
          socket
          |> put_flash(:info, "Transaction successfully deleted!")
          |> push_patch(to: ~p"/?#{[from: "delete"]}")

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
    case Transactions.update_order(old_index, new_index, socket.assigns.transactions) do
      {:ok, _} ->
        {
          :noreply,
          socket
          |> reload_transactions()
        }

      _ ->
        {
          :noreply,
          socket
          |> put_flash(:error, "Something went wrong when reordering.")
        }
    end
  end

  defp reload_transactions(socket) do
    account_ids = socket.assigns.accounts_selected_ids
    category_ids = socket.assigns.category_selected_ids

    [date_start, date_end] = socket.assigns.dates

    previous_balance =
      if socket.assigns.previous_balance do
        Transactions.balance_at(Timex.shift(date_start, days: -1),
          account_ids: account_ids,
          category_ids: category_ids
        )
      else
        Decimal.new(0)
      end

    transactions =
      Transactions.transactions_in_period(date_start, date_end,
        account_ids: account_ids,
        category_ids: category_ids
      )

    [balances, _] =
      transactions
      |> Enum.reduce([[previous_balance], previous_balance], fn ele, [acc, previous] ->
        previous = Decimal.add(previous, ele.value)

        [acc ++ [previous], previous]
      end)

    socket
    |> assign(categories: Transactions.list_categories_arranged())
    |> assign(accounts: Transactions.list_accounts())
    |> assign(transactions: transactions)
    |> assign(balances: balances)
  end

  def accounts_selected(accounts_ids, accounts) when is_list(accounts_ids) do
    accounts
    |> Enum.filter(&(&1.id in accounts_ids))
  end

  def accounts_selected(_par1, _par2) do
    []
  end

  def render_categories([], _socket), do: nil

  def render_categories(categories, category_selected_ids, socket) do
    assigns = %{
      categories: categories,
      socket: socket,
      category_selected_ids: category_selected_ids
    }

    ~H"""
    <%= for {category, children} <- @categories do %>
      <div class="flex mt-2">
        <div>

          <%= if length(category.path) > 0, do: "└ " %> 
          <input type="checkbox" phx-click="toggle-category" phx-value-category-id={category.id} checked={category.id in @category_selected_ids} />
          <.link patch={~p"/categories/#{category}/edit"}>
            <%= category.name %>
          </.link>
        </div>
        <div class="ml-auto">
          <.link_button patch={~p"/categories/#{category}/children/new"} small class="px-2">+</.link_button>
          <%= if category.transactions_count == 0 do %>
            <.link_button patch={~p"/categories/#{category}/delete"} small color="danger" class="px-2">-</.link_button>
          <% else %>
            <.tooltiped id={"not-delete-#{category.id}"} tooltip="You cannot delete this category because it has transactions associated.">
              <.icon name="hero-exclamation-circle" />
            </.tooltiped>
          <% end %>
        </div>

      </div>
      <div :if={length(children) > 0} class="pl-1 ml-3">
        <%= render_categories(children, @category_selected_ids, @socket) %>
      </div>
    <% end %>
    """
  end

  @impl true
  def handle_info(:add_new_transaction, socket) do
    {:noreply, socket |> push_patch(to: ~p"/transactions/new")}
  end

  def description(transaction) do
    case Transactions.originator(transaction) do
      %Transactions.Originator.Regular{} = regular ->
        regular.description

      %Transactions.Originator.Transfer{} ->
        other_part = Transactions.get_counter_part(transaction)

        if transaction.value |> Decimal.negative?() do
          "Transfer to '#{other_part.account.name}'"
        else
          "Transfer from '#{other_part.account.name}'"
        end
    end
  end

  def category_tooltip(categories, category) do
    {tooltip, _} =
      Enum.reduce(category.path, {"", categories}, fn id, {acc, categories} ->
        {category, children} =
          Enum.find(categories, fn {category, _} ->
            category.id == id
          end)

        {acc <> category.name <> " > ", children}
      end)

    tooltip <> category.name
  end
end

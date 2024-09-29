defmodule BudgetWeb.BudgetLive.Index do

  use BudgetWeb, :live_view

  alias Phoenix.LiveView.JS

  alias Budget.Transactions
  alias Budget.Transactions.Transaction

  @date_format "{YYYY}-{0M}-{0D}"

  @impl true
  def mount(params, _session, socket) do
    {
      :ok,
      socket
      |> assign(confirm_delete: nil)
      |> assign(balances: [0, 0])
      |> assign(new_transaction_payload: %Transaction{date: Timex.today()})
      |> assign(previous_balance: true)
      |> assign(partial_balance: false)
      |> assign(url_params: params)
      |> reload_transactions()
    }
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = 
      socket
      |> assign(url_params: params)
      |> apply_action(socket.assigns.live_action, params)
      |> apply_return_from(Map.get(params, "from", ""), params)

    {
      :noreply,
      socket
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
      when from in ["account", "delete", "category", "date"] do
    reload_transactions(socket)
  end

  def apply_return_from(socket, _, _), do: socket

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

  def handle_event("transaction-delete", %{"delete-mode" => delete_mode}, socket) do
    transaction_id = socket.assigns.confirm_delete.transaction_id

    params = Map.put(socket.assigns.url_params, "from", "delete")

    socket =
      case Transactions.delete_transaction(transaction_id, delete_mode) do
        {:ok, _} ->
          socket
          |> put_flash(:info, "Transaction successfully deleted!")
          |> push_patch(to: ~p"/?#{params}")

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

  defp get_dates(url_params) do
    date_start = Map.get(url_params, "date_start")
    date_end = Map.get(url_params, "date_end")

    if date_start && date_end do
      [
        Timex.parse!(date_start, @date_format),
        Timex.parse!(date_end, @date_format)
      ]
    else
      [Timex.beginning_of_month(Timex.today()), Timex.end_of_month(Timex.today())]
    end
  end

  defp get_categories(url_params) do
    category_ids = Map.get(url_params, "category_ids", "") |> String.split(",")

    if category_ids == [""] do
      []
    else 
      category_ids
      |> Enum.map(&String.to_integer/1)
    end
  end

  defp get_accounts(url_params) do
    account_ids = Map.get(url_params, "account_ids", "") |> String.split(",")

    if account_ids == [""] do
      []
    else 
      account_ids
      |> Enum.map(&String.to_integer/1)
    end

  end

  defp reload_transactions(socket) do
    [date_start, date_end] = get_dates(socket.assigns.url_params)
    
    account_ids = get_accounts(socket.assigns.url_params)
    category_ids = get_categories(socket.assigns.url_params)

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

  @impl true
  def handle_info(:add_new_transaction, socket) do
    url_params = 
      socket.assigns.url_params
      |> Map.delete("account_id")
      |> Map.delete("date")
      |> Map.delete("transaction-add-new")

    {:noreply, socket |> push_patch(to: ~p"/transactions/new?#{url_params}")}
  end

  def handle_info({:accounts_selected_ids, ids}, socket) do
    url_params = socket.assigns.url_params
    params = 
      if length(ids) == 0 do
        url_params
        |> Map.delete("account_ids")
      else
        url_params
        |> Map.put("account_ids", Enum.join(ids, ","))
        |> Map.put("from", "account")
      end

    {
      :noreply,
      socket
      |> push_patch(to: ~p"/?#{params}")
    }
  end

  def handle_info({:category_selected_ids, ids}, socket) do
    url_params = socket.assigns.url_params
    params = 
      if length(ids) == 0 do
        url_params
        |> Map.delete("category_ids")
      else
        url_params
        |> Map.put("category_ids", Enum.join(ids, ","))
        |> Map.put("from", "category")
      end

    {
      :noreply,
      socket
      |> push_patch(to: ~p"/?#{params}")
    }
  end

  def handle_info({:dates, [date_start, date_end]}, socket) do
    date_start = Timex.format!(date_start, @date_format)
    date_end = Timex.format!(date_end, @date_format)

    params = 
      socket.assigns.url_params
      |> Map.put("date_start", date_start)
      |> Map.put("date_end", date_end)
      |> Map.put("from", "date")

    {
      :noreply,
      socket
      |> push_patch(to: ~p"/?#{params}")
    }
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

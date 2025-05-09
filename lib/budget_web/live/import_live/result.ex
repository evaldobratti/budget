defmodule BudgetWeb.ImportLive.Result do
  use BudgetWeb, :live_view

  alias Ecto.Changeset
  alias Budget.Hinter
  alias Budget.Transactions
  alias Budget.Importations

  def mount(_, _, socket) do
    accounts = Transactions.list_accounts()
    account = accounts |> Enum.at(0)

    {
      :ok,
      socket
      |> assign(:step, :input_json)
      |> assign(result: %{transactions: []})
      |> assign(changes: [])
      |> assign(accounts: accounts)
      |> assign(account: account)
      |> assign(categories: Transactions.list_categories())
      |> apply_changes()
    }
  end

  def handle_event("json", %{"json" => json}, socket) do
    Jason.decode(json)
    |> case do
      {:ok, result} ->
        result =
          result
          |> Enum.with_index()
          |> Enum.map(fn {transaction, ix} ->
            if transaction["type"] == "transaction" do
              hint =
                case Hinter.hint_description(transaction["description"]) do
                  [hint | _] when hint.rank > 0.9 -> hint.suggestion
                  _ -> transaction["description"]
                end

              category = Hinter.hint_category(transaction["description"], nil)

              %{
                "type" => :transaction,
                "ix" => ix,
                "date" => transaction["date"],
                "value" => transaction["value"],
                "originator" => "regular",
                "regular" => %{
                  "category_id" => Map.get(category || %{}, :id),
                  "description" => hint,
                  "original_description" => transaction["description"]
                },
                "transfer" => %{
                  "other_account_id" => nil
                }
              }
            else
              %{"type" => :page_break, "ix" => ix}
            end
          end)

        socket =
          socket
          |> assign(result: %{ transactions: result })
          |> apply_changes()
          |> assign(:step, :import)

        {:noreply, socket}

      {:error, error} ->
        IO.inspect(error)
        {:noreply, socket}
    end
  end

  def handle_event("change-account-id", %{"account_id" => account_id}, socket) do
    account = socket.assigns.accounts |> Enum.find(&(&1.id == String.to_integer(account_id)))

    {
      :noreply,
      socket
      |> assign(account: account)
      |> apply_changes()
    }
  end

  def handle_event("validate-" <> ix, payload, socket) do
    {
      :noreply,
      socket
      |> update(:changes, fn changes ->
        change =
          payload
          |> Map.delete("_target")
          |> Map.get("form")
          |> Map.put("ix", String.to_integer(ix))

        [{:change, change} | changes]
      end)
      |> apply_changes()
    }
  end

  def handle_event("delete-" <> ix, _payload, socket) do
    {
      :noreply,
      socket
      |> update(:changes, fn changes -> [{:delete, String.to_integer(ix)} | changes] end)
      |> apply_changes()
    }
  end

  def handle_event("import", _, socket) do
    changesets =
      socket.assigns.changesets
      |> Enum.filter(&match?(%Changeset{}, &1))
      |> Enum.map(&Map.put(&1, :action, :insert))

    all_valid? = Enum.all?(changesets, & &1.valid?)

    if all_valid? do
      case Importations.insert(changesets) do
        {:ok, _} ->
          {:noreply, push_navigate(socket, to: "/")}

        _ ->
          {:noreply, socket}
      end
    else
      {
        :noreply,
        socket
        |> assign(:changesets, changesets)
      }
    end
  end

  defp apply_changes(socket) do
    changesets =
      socket.assigns.changes
      |> Enum.reverse()
      |> Enum.reduce(socket.assigns.result.transactions, fn
        {:change, change}, acc ->
          Enum.map(acc, fn original ->
            if Map.get(original, "ix") == Map.get(change, "ix") do
              MapUtils.deep_merge(original, change)
            else
              original
            end
          end)

        {:delete, ix}, acc ->
          Enum.filter(acc, &(Map.get(&1, "ix") !== ix))
      end)
      |> Enum.map(fn
        %{"type" => :transaction} = attrs ->
          attrs
          |> Map.put("account_id", socket.assigns.account.id)
          |> Transactions.Transaction.Form.insert_changeset()

        other ->
          other
      end)

    socket
    |> assign(changesets: changesets)
  end
end

defmodule MapUtils do
  def deep_merge(left, right) do
    Map.merge(left, right, &deep_resolve/3)
  end

  # Key exists in both maps, and both values are maps as well.
  # These can be merged recursively.
  defp deep_resolve(_key, left = %{}, right = %{}) do
    deep_merge(left, right)
  end

  # Key exists in both maps, but at least one of the values is
  # NOT a map. We fall back to standard merge behavior, preferring
  # the value on the right.
  defp deep_resolve(_key, _left, right) do
    right
  end
end

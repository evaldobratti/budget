defmodule BudgetWeb.TransactionLive.FormComponent do
  use BudgetWeb, :live_component

  alias Ecto.Changeset

  alias Budget.Transactions
  alias Budget.Transactions.Transaction
  alias Budget.Transactions.Recurrency
  alias Budget.Hinter

  defp changeset(assigns, params \\ %{})

  defp changeset(%{action: :edit_transaction, transaction: transaction}, params) do
    transaction
    |> Transaction.Form.decorate()
    |> Transaction.Form.update_changeset(params)
  end

  defp changeset(%{action: :new_transaction, transaction: transaction}, params) do
    params =
      params
      |> Map.put_new("date", transaction.date || Timex.today())
      |> Map.put_new("originator", "regular")
      |> Map.put_new("keep_adding", true)
      |> Map.put_new("account_id", transaction.account_id)

    Transaction.Form.insert_changeset(params)
  end

  @impl true
  def update(assigns, socket) do
    {
      :ok,
      socket
      |> assign(assigns)
      |> assign(form: to_form(changeset(assigns)))
      |> assign(accounts: Transactions.list_accounts())
      |> assign(categories: arrange_categories())
      |> assign(descriptions: Transactions.list_descriptions())
    }
  end

  @impl true
  def handle_event("validate", %{"form" => form_params} = params, socket) do
    form =
      socket.assigns
      |> changeset(form_params)
      |> hint_category(Map.get(params, "_target"))
      |> Map.put(:action, :validate)
      |> to_form

    {:noreply, assign(socket, form: form)}
  end

  def hint_category(changeset, ["form", "regular", "description"]) do
    account_id = Changeset.get_field(changeset, :accunt_id)

    description =
      changeset
      |> Changeset.get_change(:regular)
      |> Changeset.get_field(:description)

    case Hinter.hint_category(description, account_id) do
      nil ->
        changeset

      category ->
        regular_changeset =
          changeset
          |> Changeset.get_change(:regular)
          |> Changeset.put_change(:category_id, category.id)

        Changeset.put_embed(
          changeset,
          :regular,
          regular_changeset
        )
    end
  end

  def hint_category(changeset, _), do: changeset

  def handle_event("save", %{"form" => form_params}, socket) do
    save_transaction(
      socket,
      socket.assigns.action,
      changeset(socket.assigns, form_params)
    )
  end

  def save_transaction(socket, :edit_transaction, changeset) do
    case Transaction.Form.apply_update(changeset, socket.assigns.transaction) do
      {:ok, _transaction} ->
        {
          :noreply,
          socket
          |> put_flash(:info, "Transaction updated successfully!")
          |> push_patch(to: socket.assigns.patch)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def save_transaction(socket, :new_transaction, changeset) do
    case Transaction.Form.apply_insert(changeset) do
      {:ok, _transaction} ->
        patch =
          if Changeset.get_change(changeset, :keep_adding) do
            uri = URI.parse(socket.assigns.patch)
            date = Changeset.get_change(changeset, :date)
            account_id = Changeset.get_change(changeset, :account_id)

            query =
              uri.query
              |> URI.decode_query()
              |> Enum.into(%{})
              |> Map.put("transaction-add-new", true)
              |> Map.put("account_id", account_id)
              |> Map.put("date", date |> Date.to_iso8601())
              |> URI.encode_query()

            %{uri | query: query} |> URI.to_string()
          else
            socket.assigns.patch
          end

        {
          :noreply,
          socket
          |> put_flash(:info, "Transaction created successfully!")
          |> push_patch(to: patch)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def arrange_categories do
    Transactions.list_categories_arranged()
    |> Enum.flat_map(&flatten_categories/1)
  end

  def flatten_categories({category, []}) do
    spaces = String.duplicate("&#160;", length(category.path) * 8)

    [{{:safe, spaces <> category.name}, category.id}]
  end

  def flatten_categories({category, categories}) do
    spaces = String.duplicate("&#160;", length(category.path) * 8)

    [
      {{:safe, spaces <> category.name}, category.id}
    ] ++ Enum.flat_map(categories, &flatten_categories/1)
  end
end

defmodule BudgetWeb.TransactionLive.FormComponent do
  use BudgetWeb, :live_component

  alias Budget.Transactions
  alias Budget.Transactions.Transaction
  alias Budget.Transactions.Recurrency

  defp changeset(assigns, params \\ %{})

  defp changeset(%{action: :edit_transaction, transaction: transaction}, params) do
    transaction
    |> Transaction.Form.decorate()
    |> Transaction.Form.update_changeset(params)
  end

  defp changeset(%{action: :new_transaction}, params) do
    params =
      params
      |> Map.put_new("date", Timex.today())
      |> Map.put_new("originator", "regular")
      |> Map.put_new("keep_adding", true)

    Transaction.Form.insert_changeset(params)
  end

  @impl true
  def update(assigns, socket) do
    {
      :ok,
      socket
      |> assign(assigns)
      |> assign(changeset: changeset(assigns))
      |> assign(accounts: Transactions.list_accounts())
      |> assign(categories: Transactions.list_categories())
    }
  end

  @impl true
  def handle_event("validate", %{"form" => form_params}, socket) do
    changeset =
      socket.assigns
      |> changeset(form_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

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
          |> push_patch(to: socket.assigns.return_to)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def save_transaction(socket, :new_transaction, changeset) do
    case Transaction.Form.apply_insert(changeset) do
      {:ok, _transaction} ->
        return_to =
          if Ecto.Changeset.get_change(changeset, :keep_adding) do
            uri = URI.parse(socket.assigns.return_to)

            query =
              uri.query
              |> URI.decode_query()
              |> Enum.into(%{})
              |> Map.put("transaction-add-new", true)
              |> URI.encode_query()

            %{uri | query: query} |> URI.to_string()
          else
            socket.assigns.return_to
          end

        {
          :noreply,
          socket
          |> put_flash(:info, "Transaction created successfully!")
          |> push_patch(to: return_to)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end

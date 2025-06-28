defmodule BudgetWeb.TransactionLive.FormComponent do
  require Decimal
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
      |> Map.put_new("account_id", transaction.account_id)

    Transaction.Form.insert_changeset(params)
  end

  @impl true
  def update(assigns, socket) do
    assigns = Map.put_new(assigns, :on_cancel, nil)

    {
      :ok,
      socket
      |> assign(assigns)
      |> assign(form: to_form(changeset(assigns), id: to_string(assigns.id)))
      |> assign(accounts: Transactions.list_accounts())
      |> assign(categories: arrange_categories())
      |> assign(descriptions: Transactions.list_descriptions())
      |> assign(hint_descriptions: [])
    }
  end

  @impl true
  def handle_event("validate", %{"form" => form_params} = params, socket) do
    changeset =
      socket.assigns
      |> changeset(form_params)
      |> Map.put(:action, :validate)

    [changeset, socket] = hint_description(changeset, Map.get(params, "_target"), socket)

    changeset = hint_category(changeset, Map.get(params, "_target"))

    {:noreply, assign(socket, form: to_form(changeset, id: to_string(socket.assigns.id)))}
  end

  def handle_event("save", %{"form" => form_params}, socket) do
    save_transaction(
      socket,
      socket.assigns.action,
      changeset(socket.assigns, form_params)
    )
  end

  def hint_category(changeset, ["form", "regular", field])
      when field in ["description", "original_description"] do
    # TODO a global search seems better than account specific
    _account_id = Changeset.get_field(changeset, :account_id)

    description =
      changeset
      |> Changeset.get_change(:regular)
      |> Changeset.get_field(:description)

    case Hinter.hint_category(description, nil) do
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

  def hint_description(changeset, ["form", "regular", "original_description"], socket) do
    description =
      changeset
      |> Changeset.get_change(:regular)
      |> Changeset.get_field(:original_description)

    selected_option = Enum.find(socket.assigns.hint_descriptions, &(&1.original == description))

    if selected_option do
      regular_changeset =
        changeset
        |> Changeset.get_change(:regular)
        |> Changeset.put_change(:description, selected_option.suggestion)

      [
        Changeset.put_embed(
          changeset,
          :regular,
          regular_changeset
        ),
        socket
      ]
    else
      hints = Hinter.hint_description(description)

      [
        changeset,
        socket
        |> assign(:hint_descriptions, hints)
      ]
    end
  end

  def hint_description(changeset, _, socket), do: [changeset, socket]

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
        {:noreply, assign(socket, form: to_form(changeset, id: to_string(socket.assigns.id)))}
    end
  end

  def save_transaction(socket, :new_transaction, changeset) do
    case Transaction.Form.apply_insert(changeset) do
      {:ok, transaction} ->
        uri = URI.parse(socket.assigns.patch)

        query =
          uri.query
          |> URI.decode_query()
          |> Enum.into(%{})
          |> Map.put("transaction_id", transaction.id)
          |> URI.encode_query()

        patch = %{uri | query: query} |> URI.to_string()

        {
          :noreply,
          socket
          |> assign(
            form:
              to_form(
                changeset(%{action: :new_transaction, transaction: socket.assigns.transaction})
              )
          )
          |> put_flash(:info, "Transaction created successfully!")
          |> push_patch(to: patch)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, id: to_string(socket.assigns.id)))}
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

  def render_parcels(form, _recurrency_form) do
    recurrency_changeset = form[:recurrency].value
    parcel_start = Changeset.get_field(recurrency_changeset, :parcel_start)
    parcel_end = Changeset.get_field(recurrency_changeset, :parcel_end)
    value = form[:value].value

    assigns = %{
      parcel_start: parcel_start,
      parcel_end: parcel_end,
      value: value
    }

    cond do
      parcel_start == nil ->
        nil

      parcel_end == nil ->
        nil

      !Decimal.is_decimal(value) ->
        nil

      true ->
        ~H"""
          <div>
            Total cost: <%= Decimal.mult((@parcel_end - @parcel_start + 1), @value) %>
          </div>
        """
    end
  end
end

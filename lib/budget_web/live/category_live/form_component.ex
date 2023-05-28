defmodule BudgetWeb.CategoryLive.FormComponent do
  use BudgetWeb, :live_component

  alias Budget.Transactions

  @impl true
  def update(%{category: category} = assigns, socket) do
    changeset = Transactions.change_category(category)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"category" => category_params}, socket) do
    changeset =
      socket.assigns.category
      |> Transactions.change_category(category_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"category" => category_params}, socket) do
    save_category(socket, socket.assigns.action, category_params)
  end

  defp save_category(socket, :edit_category, category_params) do
    case Transactions.update_category(socket.assigns.category, category_params) do
      {:ok, _category} ->
        {
          :noreply,
          socket
          |> put_flash(:info, "Category updated successfully")
          |> push_patch(to: socket.assigns.patch)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_category(socket, :new_category, category_params) do
    case Transactions.create_category(category_params, Map.get(socket.assigns, :parent)) do
      {:ok, _category} ->
        {
          :noreply,
          socket
          |> put_flash(:info, "Category created successfully")
          |> push_patch(to: socket.assigns.patch)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end

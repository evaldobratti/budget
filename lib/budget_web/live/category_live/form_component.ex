defmodule BudgetWeb.CategoryLive.FormComponent do
  use BudgetWeb, :live_component

  alias Budget.Entries

  @impl true
  def update(%{category: category} = assigns, socket) do
    changeset = Entries.change_category(category)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"category" => category_params}, socket) do
    changeset =
      socket.assigns.category
      |> Entries.change_category(category_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"category" => category_params}, socket) do
    save_category(socket, socket.assigns.action, category_params)
  end

  defp save_category(socket, :edit_category, category_params) do
    case Entries.update_category(socket.assigns.category, category_params) do
      {:ok, _category} ->
        {
          :noreply,
          socket
          |> put_flash(:info, "Category updated successfully")
          |> push_patch(to: socket.assigns.return_to)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_category(socket, :new_category, category_params) do
    case Entries.create_category(category_params) do
      {:ok, _category} ->
        {
          :noreply,
          socket
          |> put_flash(:info, "Category created successfully")
          |> push_patch(to: socket.assigns.return_to)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end

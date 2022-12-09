defmodule BudgetWeb.RecurrencyLive.FormComponent do
  use BudgetWeb, :live_component

  alias Budget.Entries

  @impl true
  def update(%{recurrency: recurrency} = assigns, socket) do
    changeset =
      if assigns.action == :new do
        Entries.change_recurrency(recurrency, %{date_start: Date.utc_today()})
      else
        Entries.change_recurrency(recurrency)
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)
     |> assign(:accounts, Entries.list_accounts())}
  end

  @impl true
  def handle_event("validate", %{"recurrency" => recurrency_params}, socket) do
    changeset =
      socket.assigns.recurrency
      |> Entries.change_recurrency(recurrency_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"recurrency" => recurrency_params}, socket) do
    save_recurrency(socket, socket.assigns.action, recurrency_params)
  end

  defp save_recurrency(socket, :edit, recurrency_params) do
    case Entries.update_recurrency(socket.assigns.recurrency, recurrency_params) do
      {:ok, recurrency} ->
        send(self(), recurrency_updated: recurrency)

        {
          :noreply,
          socket
          |> put_flash(:info, "Recurrency updated successfully")
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_recurrency(socket, :new, recurrency_params) do
    case Entries.create_recurrency(recurrency_params) do
      {:ok, recurrency} ->
        send(self(), recurrency_created: recurrency)

        {
          :noreply,
          socket
          |> put_flash(:info, "Recurrency created successfully")
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end

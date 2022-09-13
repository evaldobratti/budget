defmodule BudgetWeb.EntryLive.FormComponent do
  use BudgetWeb, :live_component

  alias Budget.Entries

  @impl true
  def update(%{entry: entry} = assigns, socket) do
    changeset = 
      if assigns.action == :new do
        Entries.change_entry(entry, %{date: Date.utc_today()})
      else
        Entries.change_entry(entry)
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)
     |> assign(:accounts, Entries.list_accounts())
    }
  end

  @impl true
  def handle_event("validate", %{"entry" => entry_params}, socket) do
    changeset =
      socket.assigns.entry
      |> Entries.change_entry(entry_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"entry" => entry_params}, socket) do
    save_entry(socket, socket.assigns.action, entry_params)
  end

  defp save_entry(socket, :edit, entry_params) do
    case Entries.update_entry(socket.assigns.entry, entry_params) do
      {:ok, entry} ->
        send(self(), entry_updated: entry)

        {
          :noreply,
          socket
          |> put_flash(:info, "Entry updated successfully")
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_entry(socket, :new, entry_params) do
    case Entries.create_entry(entry_params) do
      {:ok, entry} ->
        send(self(), entry_created: entry)

        {
          :noreply,
          socket
          |> put_flash(:info, "Entry created successfully")
          |> assign(changeset: Entries.change_entry(%Entries.Entry{}))
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end

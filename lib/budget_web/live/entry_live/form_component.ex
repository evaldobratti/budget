defmodule BudgetWeb.EntryLive.FormComponent do
  use BudgetWeb, :live_component

  alias Budget.Entries
  alias Budget.Entries.Entry
  alias Budget.Entries.Recurrency

  @impl true
  def update(assigns, socket) do
    changeset = Entries.change_entry(assigns.entry)

    {
      :ok,
      socket
      |> assign(assigns)
      |> assign(changeset: changeset)
      |> assign(accounts: Entries.list_accounts())
      |> assign(categories: Entries.list_categories())
    }
  end

  @impl true
  def handle_event("validate", %{"entry" => entry_params} = params, socket) do
    changeset =
      socket.assigns.entry
      |> Entries.change_entry(entry_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"entry" => entry_params} = params, socket) do
    save_entry(socket, socket.assigns.action, entry_params, Map.get(params, "keep_adding", "false") == "true")
  end

  def save_entry(socket, :edit_entry, entry_params, _keep_adding) do
    entry = socket.assigns.entry


    result = 
      case entry.id do
        "recurrency" <> _ ->
          recurrency_entry = entry.recurrency_entry

          entry = %{entry | recurrency_entry: %{recurrency_entry | id: nil}}

          Entries.create_entry(entry, entry_params)

        _ -> 
          Entries.update_entry(entry, entry_params) 
      end

    case result do
      {:ok, _entry} ->
        {
          :noreply,
          socket
          |> put_flash(:info, "Entry updated successfully!")
          |> push_patch(to: socket.assigns.return_to)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def save_entry(socket, :new_entry, entry_params, keep_adding) do
    entry_params
    |> Entries.create_entry()
    |> case do
      {:ok, _entry} ->
        return_to = 
          if keep_adding do
            "/?from=entry&entry-add-new=true"
          else
            socket.assigns.return_to
          end

        {
          :noreply,
          socket
          |> put_flash(:info, "Entry created successfully!")
          |> push_patch(to: return_to)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end

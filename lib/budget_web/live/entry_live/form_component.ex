defmodule BudgetWeb.EntryLive.FormComponent do
  use BudgetWeb, :live_component

  alias Budget.Entries
  alias Budget.Entries.Entry
  alias Budget.Entries.Recurrency

  defp changeset(assigns, params \\ %{})

  defp changeset(%{action: :edit_entry, entry: entry}, params) do
    entry
    |> Entry.Form.decorate()
    |> Entry.Form.update_changeset(params)
  end

  defp changeset(%{action: :new_entry}, params) do
    params = 
      params
      |> Map.put_new("date", Timex.today())
      |> Map.put_new("originator", "regular")
      |> Map.put_new("keep_adding", true)

    Entry.Form.insert_changeset(params)
  end

  @impl true
  def update(assigns, socket) do
    {
      :ok,
      socket
      |> assign(assigns)
      |> assign(changeset: changeset(assigns))
      |> assign(accounts: Entries.list_accounts())
      |> assign(categories: Entries.list_categories())
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
    save_entry(
      socket,
      socket.assigns.action,
      changeset(socket.assigns, form_params)
    )
  end

  def save_entry(socket, :edit_entry, changeset) do
    case Entry.Form.apply_update(changeset, socket.assigns.entry) do
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

  def save_entry(socket, :new_entry, changeset) do
    case Entry.Form.apply_insert(changeset) do
      {:ok, _entry} ->
        return_to =
          if Ecto.Changeset.get_change(changeset, :keep_adding) do
            uri = URI.parse(socket.assigns.return_to)

            query =
              uri.query
              |> URI.decode_query()
              |> Enum.into(%{})
              |> Map.put("entry-add-new", true)
              |> URI.encode_query()

            %{uri | query: query} |> URI.to_string()
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

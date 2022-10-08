defmodule BudgetWeb.EntryLive.FormComponent do
  use BudgetWeb, :live_component

  alias Budget.Entries
  alias Budget.Entries.Entry
  alias Budget.Entries.Recurrency

  @impl true
  def update(%{action: action} = assigns, socket) do
    changeset = 
      if action == :new_entry do
        Entries.change_entry(assigns.entry)
      else
        Entries.change_entry(assigns.entry)
      end

    {
      :ok, 
      socket
      |> assign(assigns)
      |> assign(changeset: changeset)
      |> assign(accounts: Entries.list_accounts())
    }
  end

  @impl true
  def handle_event("validate", %{"entry" => entry_params}, socket) do
    changeset = 
      socket.assigns.entry
      |> Entries.change_entry(mount_params(entry_params))
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"entry" => entry_params}, socket) do
    save_entry(socket, socket.assigns.action, entry_params)
  end

  def save_entry(socket, :edit_entry, _entry_params) do
    action = 
      socket.assigns.changeset
      |> Ecto.Changeset.apply_action(:update)

    case action do
      {:ok, %{recurrency: nil, entry: entry}} ->
        entry_attrs = 
          entry
          |> Map.from_struct()
          |> Map.put(:recurrency_entry, nil)

        {:ok, _} = Entries.update_entry(socket.assigns.entry, entry_attrs)

        {
          :noreply, 
          socket
          |> put_flash(:info, "Entry updated successfully")
          |> push_patch(to: socket.assigns.return_to)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end

  end

  def save_entry(socket, :new_entry, entry_params) do
    entry_params = mount_params(entry_params)

    entry_params
    |> Entries.create_entry()
    |> case do
      {:ok, _entry} ->
        {
          :noreply, 
          socket
          |> put_flash(:info, "Entry created successfully")
          |> push_patch(to: socket.assigns.return_to)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def mount_params(entry_params) do
    if Map.get(entry_params, "is_recurrency") == "true" do
      recurrency_entry_params = Map.get(entry_params, "recurrency_entry", %{})
      recurrency_params = Map.get(recurrency_entry_params, "recurrency", %{})

      possible_params = possible_recurrency_params(entry_params)

      Map.put(
        entry_params, 
        "recurrency_entry", 
        Map.put(
          recurrency_entry_params, 
          "recurrency", 
          Map.merge(
            recurrency_params, 
            possible_params
          )
        )
        |> Map.put("original_date", possible_params["date_start"])
      )
    else
      entry_params
    end
  end

  def possible_recurrency_params(entry_params) do
    changeset = Entry.changeset(%Entry{}, entry_params)

    %{
      "date_start" => Ecto.Changeset.get_field(changeset, :date),
      "description" => Ecto.Changeset.get_field(changeset, :description),
      "value" => Ecto.Changeset.get_field(changeset, :value),
      "account_id" => Ecto.Changeset.get_field(changeset, :account_id),
      "frequency" => "monthly"
    }
  end

end



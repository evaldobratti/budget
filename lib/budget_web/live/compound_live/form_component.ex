defmodule BudgetWeb.CompoundLive.FormComponent do
  use BudgetWeb, :live_component

  alias Budget.Entries
  alias Budget.Entries.Recurrency
  alias BudgetWeb.CompoundLive.CompoundEntry


  @impl true
  def update(%{action: action}, socket) do
    changeset = 
      if action == :new do
        CompoundEntry.changeset(%CompoundEntry{
          entry: %Entries.Entry{date: Timex.today()}, 
          is_recurrency: false,
          recurrency: nil
        })
      else
        TODO
      end

    {
      :ok, 
      socket
      |> assign(compound_entry: changeset.data)
      |> assign(changeset: changeset)
      |> assign(action: action)
      |> assign(:accounts, Entries.list_accounts())
    }
  end

  @impl true
  def handle_event("validate", %{"compound_entry" => compound_entry_params}, socket) do
    changeset = 
      mount_changeset(socket, compound_entry_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"compound_entry" => compound_entry}, socket) do
    save_entry(socket, socket.assigns.action, compound_entry)
  end

  def save_entry(socket, :new, compound_entry_params) do
    action = 
      socket
      |> mount_changeset(compound_entry_params)
      |> Ecto.Changeset.apply_action(:insert)

    case action do
      {:ok, %{recurrency: nil, entry: entry}} ->
        entry_attrs = 
          entry
          |> Map.from_struct() 
          |> Map.put(:recurrency_entry, nil)

        {:ok, _} = Entries.create_entry(entry_attrs)

        send(self(), entry_created: entry)

        {:noreply, socket}

      {:ok, %{recurrency: recurrency, entry: entry}} ->
        entry_attrs = 
          entry
          |> Map.from_struct() 
          |> Map.put(:recurrency_entry, nil)

        {:ok, entry} = Entries.create_entry(entry_attrs)

        {:ok, _recurrency} = 
          Entries.create_recurrency(
            recurrency
            |> Map.from_struct()
            |> Map.put(:recurrency_entries, [%{entry_id: entry.id, original_date: recurrency.date_start}])
          )

        send(self(), entry_created: entry)

        {
          :noreply,
          socket
          |> put_flash(:info, "Entry created successfully")
          |> assign(changeset: CompoundEntry.changeset(%CompoundEntry{
            entry: %Entries.Entry{}, 
            is_recurrency: false,
            recurrency: nil
          }))
        }
        
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def mount_changeset(socket, compound_entry_params) do
    recurrency_params = CompoundEntry.possible_recurrency_params(compound_entry_params)

    compound_entry_params = 
      Map.update(
        compound_entry_params, 
        "recurrency", 
        recurrency_params, 
        & Map.merge(&1, recurrency_params)
      )

    socket.assigns.compound_entry
    |> CompoundEntry.changeset(compound_entry_params)
  end

end



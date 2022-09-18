defmodule BudgetWeb.CompoundLive.FormComponent do
  use BudgetWeb, :live_component

  alias Budget.Entries
  alias BudgetWeb.CompoundLive.CompoundEntry


  @impl true
  def update(%{entry: entry, action: action} = assigns, socket) do
    changeset = 
      if action == :new do
        CompoundEntry.changeset(%CompoundEntry{
          entry: entry, 
          is_recurrency: false
        })
      else
        TODO
      end

    {
      :ok, 
      socket
      |> assign(changeset: changeset)
    }
  end
end



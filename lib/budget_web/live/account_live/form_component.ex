defmodule BudgetWeb.AccountLive.FormComponent do
  use BudgetWeb, :live_component

  alias Budget.Entries

  @impl true
  def update(%{account: account} = assigns, socket) do
    changeset = Entries.change_account(account)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"account" => account_params}, socket) do
    changeset =
      socket.assigns.account
      |> Entries.change_account(account_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"account" => account_params}, socket) do
    save_account(socket, socket.assigns.action, account_params)
  end

  defp save_account(socket, :edit_account, account_params) do
    case Entries.update_account(socket.assigns.account, account_params) do
      {:ok, account} ->
        send(self(), account_updated: account)

        {
          :noreply,
          socket
          |> put_flash(:info, "Account updated successfully")
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_account(socket, :new_account, account_params) do
    case Entries.create_account(account_params) do
      {:ok, _account} ->
        {
          :noreply,
          socket
          |> put_flash(:info, "Account created successfully")
          |> push_patch(to: socket.assigns.return_to)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end

defmodule BudgetWeb.AccountLive.FormComponent do
  use BudgetWeb, :live_component

  alias Budget.Transactions

  @impl true
  def update(%{account: account} = assigns, socket) do
    changeset = Transactions.change_account(account)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"account" => account_params}, socket) do
    changeset =
      socket.assigns.account
      |> Transactions.change_account(account_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"account" => account_params}, socket) do
    save_account(socket, socket.assigns.action, account_params)
  end

  defp save_account(socket, :edit_account, account_params) do
    case Transactions.update_account(socket.assigns.account, account_params) do
      {:ok, _account} ->
        {
          :noreply,
          socket
          |> put_flash(:info, "Account updated successfully")
          |> push_patch(to: socket.assigns.patch)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_account(socket, :new_account, account_params) do
    case Transactions.create_account(account_params) do
      {:ok, _account} ->
        {
          :noreply,
          socket
          |> put_flash(:info, "Account created successfully")
          |> push_patch(to: socket.assigns.patch)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end

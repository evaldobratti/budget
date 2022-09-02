defmodule BudgetWeb.BudgetLive.Index do
  use BudgetWeb, :live_view

  alias Budget.Entries
  alias Budget.Entries.Account

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(accounts: Entries.list_accounts())
      |> assign(modal_account_action: nil)
    }
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  def handle_event("account_new", _params, socket) do
    {
      :noreply,
      socket
      |> assign(modal_account_action: :new)
      |> assign(account: %Entries.Account{})
    }
  end

  def handle_event("account_edit", %{"account-id" => account_id}, socket) do
    {
      :noreply,
      socket
      |> assign(modal_account_action: :edit)
      |> assign(account: Entries.get_account!(account_id))
    }
  end

  def handle_event("close_account_modal", _params, socket) do
    {
      :noreply,
      assign(socket, modal_account_action: nil)
    }
  end

  @impl true
  def handle_info([{action, _account}], socket) when action in [:account_created, :account_updated] do
    {
      :noreply, 
      socket
      |> assign(accounts: Entries.list_accounts())
      |> assign(modal_account_action: nil)
    }
  end

  
end

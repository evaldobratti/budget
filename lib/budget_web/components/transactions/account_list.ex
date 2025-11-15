defmodule BudgetWeb.Transactions.AccountList do

  use BudgetWeb, :live_component


  alias Budget.Transactions
  alias BudgetWeb.Helpers.UrlParams

  def mount(socket) do
    {
      :ok,
      socket
      |> assign(accounts: Transactions.list_accounts())
      |> assign(all_selected: false)
    }
  end

  def update(assigns, socket) do
    selected_ids = UrlParams.get_accounts(Map.get(assigns, :url_params))

    {
      :ok,
      socket
      |> assign(:selected_ids, selected_ids)
    }
  end

  def render(assigns) do
    assigns = Map.put_new(assigns, :url_params, %{})

    ~H"""
    <div class="flex flex-col">
      <div class="flex items-center gap-1">
        Accounts
        <div class="tooltip ml-auto" data-tip="Select all">
          <input
            type="checkbox"
            class="checkbox checkbox-xs"
            phx-click="toggle-all-accounts"
            phx-target={@myself}
            checked={@all_selected}
          />
        </div>
        <.link class="btn btn-xs" patch={~p"/accounts/new?#{@url_params}"}>New</.link>
      </div>
      <%= if Enum.empty?(@accounts) do %>
        <div class="flex flex-justify-center">
          No accounts yet
        </div>
      <% end %>
      <%= for account <- @accounts do %>
        <div class="flex items-center gap-1">
            <input 
              type="checkbox" 
              class="checkbox checkbox-xs"
              phx-click="toggle-account" 
              phx-value-account-id={account.id} 
              phx-target={@myself}
              checked={account.id in @selected_ids} 
            />
            <.link patch={~p"/accounts/#{account}/edit?#{@url_params}"}><%= account.name %></.link>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("toggle-account", %{"account-id" => account_id}, socket) do
    {account_id, _} = Integer.parse(account_id)

    accounts_selected_ids =
      if account_id in socket.assigns.selected_ids do
        List.delete(socket.assigns.selected_ids, account_id)
      else
        [account_id | socket.assigns.selected_ids]
      end

    send(self(), {:accounts_selected_ids, accounts_selected_ids})

    {
      :noreply,
      socket
    }
  end
end

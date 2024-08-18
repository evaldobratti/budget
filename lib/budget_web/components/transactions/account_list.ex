defmodule BudgetWeb.Transactions.AccountList do

  use BudgetWeb, :live_component

  def render(assigns) do
    assigns = Map.put_new(assigns, :url_params, %{})

    ~H"""
    <div class="flex flex-col">
      <div class="flex items-start mt-2">
        Accounts
        <.link_button small class="ml-auto text-center px-4" patch={~p"/accounts/new?#{@url_params}"}>New</.link_button>
      </div>
      <%= if Enum.empty?(@accounts) do %>
        <div class="flex mt-2 flex-justify-center">
          No accounts yet
        </div>
      <% end %>
      <%= for account <- @accounts do %>
        <div class="flex mt-2">
          <div>
            <input 
              type="checkbox" 
              phx-click="toggle-account" 
              phx-value-account-id={account.id} 
              phx-target={@myself}
              checked={account.id in @accounts_selected_ids} 
            />
            <.link patch={~p"/accounts/#{account}/edit?#{@url_params}"}><%= account.name %></.link>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("toggle-account", %{"account-id" => account_id}, socket) do
    {account_id, _} = Integer.parse(account_id)

    accounts_selected_ids =
      if account_id in socket.assigns.accounts_selected_ids do
        List.delete(socket.assigns.accounts_selected_ids, account_id)
      else
        [account_id | socket.assigns.accounts_selected_ids]
      end

    send(self(), {:accounts_selected_ids, accounts_selected_ids})

    {
      :noreply,
      socket
    }
  end
end

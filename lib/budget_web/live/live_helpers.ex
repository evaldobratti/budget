defmodule BudgetWeb.LiveHelpers do
  import Phoenix.LiveView
  import Phoenix.LiveView.Helpers

  alias Phoenix.LiveView.JS

  @doc """
  Renders a live component inside a modal.

  The rendered modal receives a `:return_to` option to properly update
  the URL when the modal is closed.

  ## Examples

      <.modal return_to={Routes.account_index_path(@socket, :index)}>
        <.live_component
          module={BudgetWeb.AccountLive.FormComponent}
          id={@account.id || :new}
          title={@page_title}
          action={@live_action}
          return_to={Routes.account_index_path(@socket, :index)}
          account: @account
        />
      </.modal>
  """
  def modal(assigns) do
    assigns = assign_new(assigns, :return_to, fn -> nil end)
    assigns = assign_new(assigns, :close_event, fn -> nil end)

    ~H"""
    <div id="modal" class="phx-modal fade-in" phx-remove={hide_modal()}>
      <div
        id="modal-content"
        class="phx-modal-content fade-in-scale"
        phx-click-away={JS.dispatch("click", to: "#close")}
        phx-window-keydown={JS.dispatch("click", to: "#close")}
        phx-key="escape"
      >
        <a id="close" href="#" class="phx-modal-close" phx-click={assigns.close_event}>✖</a>

        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  defp hide_modal do
    %JS{}
    |> JS.hide(to: "#modal", transition: "fade-out")
    |> JS.hide(to: "#modal-content", transition: "fade-out-scale")
end
end

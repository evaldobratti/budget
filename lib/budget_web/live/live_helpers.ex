defmodule BudgetWeb.LiveHelpers do
  import Phoenix.LiveView
  use Phoenix.Component

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

    ~H"""
    <div id="modal" class="phx-modal fade-in" phx-remove={hide_modal()}>
      <div
        id="modal-content"
        class="phx-modal-content fade-in-scale"
        phx-click-away={JS.dispatch("click", to: "#close")}
        phx-window-keydown={JS.dispatch("click", to: "#close")}
        phx-key="escape"
      >
        <div class="d-flex">
          <%= if @return_to do %>
            <%= live_patch to: @return_to,
              id: "close",
              class: "ms-auto",
              phx_click: hide_modal()
              do
            %>
              <.icon icon="fa-xmark" />
            <% end %>
          <% else %>
            <a id="close" href="#" phx-click={hide_modal()} class="ms-auto">
              <.icon icon="fa-xmark" />
            </a>
          <% end %>
        </div>
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

  def icon(assigns) do
    {icon, assigns} = Map.pop(assigns, :icon)
    phx_click = Map.get(assigns, :"phx-click")
    style = phx_click && "cursor: pointer"

    ~H"""
      <i class={"fa-solid #{icon} #{assigns[:class]}"} style={style} phx-click={phx_click} {assigns} />
    """
  end
end

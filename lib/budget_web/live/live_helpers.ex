defmodule BudgetWeb.LiveHelpers do
  import Phoenix.LiveView
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  def currency(assigns) do
    {value, assigns} = Map.pop(assigns, :value)

    color = 
      case Decimal.compare(value, 0) do
        :gt -> "color-fg-success"
        :lt -> "color-fg-danger"
        :eq -> ""
      end

    ~H"""
      <span class={color}>
        <%= Number.Currency.number_to_currency(value) %>
      </span>
    """
  end

  attr :tooltip, :string
  attr :rest, :global
  slot :inner_block
  def tooltiped(assigns) do
    ~H"""
      <span class="tooltip" 
        phx-mounted={JS.dispatch("budget:tooltip-setup")} 
        phx-remove={JS.dispatch("budget:tooltip-cleanup")} 
        {@rest}
      >
        <%= @tooltip %>
        <div class="arrow"></div>
      </span>
      <%= render_slot(@inner_block) %>
    """
  end

end

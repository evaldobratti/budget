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

end

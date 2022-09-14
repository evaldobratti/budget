defmodule BudgetWeb.ViewHelpers do

  def format_date(date) do
    Timex.format!(date, "{0D}/{0M}/{YYYY}")
  end
end

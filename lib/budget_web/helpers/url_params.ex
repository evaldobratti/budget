defmodule BudgetWeb.Helpers.UrlParams do

  def get_accounts(url_params) do
    account_ids = Map.get(url_params, "account_ids", "") |> String.split(",")

    if account_ids == [""] do
      []
    else
      account_ids
      |> Enum.map(&String.to_integer/1)
    end
  end

  def get_categories(url_params) do
    category_ids = Map.get(url_params, "category_ids", "") |> String.split(",")

    if category_ids == [""] do
      []
    else
      category_ids
      |> Enum.map(&String.to_integer/1)
    end
  end
end

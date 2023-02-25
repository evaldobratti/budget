defmodule Budget.TransactionsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Budget.Transactions` context.
  """
  alias Budget.Transactions.Transaction

  @doc """
  Generate a account.
  """
  def account_fixture(attrs \\ %{}) do
    {:ok, account} =
      attrs
      |> Enum.into(%{
        initial_balance: "120.5",
        name: "Account Name"
      })
      |> Budget.Transactions.create_account()

    account
  end

  def category_fixture(attrs \\ %{}) do
    {:ok, category} =
      attrs
      |> Enum.into(%{
        name: "root category"
      })
      |> Budget.Transactions.create_category()

    category
  end

  def transaction_fixture(attrs \\ %{}) do
    {:ok, transaction} =
      attrs
      |> Map.put_new_lazy(:account_id, fn -> account_fixture().id end)
      |> Enum.into(%{
        date: Timex.today(),
        value: 133,
        originator: "regular",
        regular: %{
          description: "Transaction description",
          category_id:
            attrs
            |> Map.get(:regular, %{})
            |> Map.get_lazy(:category_id, fn -> category_fixture().id end)
        }
      })
      |> Budget.Transactions.Transaction.Form.apply_insert()

    transaction
  end

  def recurrency_fixture(attrs \\ %{}) when is_map(attrs) do
    {:ok, transaction} =
      %{
        date: Map.get(attrs, :date, Timex.today()),
        value: Map.get(attrs, :value, 133),
        account_id: Map.get_lazy(attrs, :account_id, fn -> account_fixture().id end),
        originator: "regular",
        regular: %{
          category_id:
            attrs
            |> Map.get(:regular, %{})
            |> Map.get_lazy(:category_id, fn -> category_fixture().id end),
          description:
            attrs
            |> Map.get(:regular, %{})
            |> Map.get(:description, "Transaction description")
        },
        recurrency:
          %{
            is_parcel: false,
            is_forever: true,
            frequency: :monthly
          }
          |> Map.merge(Map.get(attrs, :recurrency, %{}))
      }
      |> Transaction.Form.apply_insert()

    Budget.Transactions.get_recurrency!(transaction.recurrency_transaction.recurrency_id)
  end
end

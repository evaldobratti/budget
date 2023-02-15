defmodule Budget.EntriesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Budget.Entries` context.
  """
  alias Budget.Entries.Entry

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
      |> Budget.Entries.create_account()

    account
  end

  def category_fixture(attrs \\ %{}) do
    {:ok, category} =
      attrs
      |> Enum.into(%{
        name: "root category"
      })
      |> Budget.Entries.create_category()

    category
  end

  def entry_fixture(attrs \\ %{}) do
    {:ok, entry} =
      attrs
      |> Map.put_new_lazy(:account_id, fn -> account_fixture().id end)
      |> Enum.into(%{
        date: Timex.today(),
        value: 133,
        originator: "regular",
        regular: %{
          description: "Entry description",
          category_id:
            attrs
            |> Map.get(:regular, %{})
            |> Map.get_lazy(:category_id, fn -> category_fixture().id end)
        }
      })
      |> Budget.Entries.Entry.Form.apply_insert()

    entry
  end

  def recurrency_fixture(attrs \\ %{}) when is_map(attrs) do
    {:ok, entry} =
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
            |> Map.get(:description, "Entry description")
        },
        recurrency:
          %{
            is_parcel: false,
            is_forever: true,
            frequency: :monthly
          }
          |> Map.merge(Map.get(attrs, :recurrency, %{}))
      }
      |> Entry.Form.apply_insert()

    Budget.Entries.get_recurrency!(entry.recurrency_entry.recurrency_id)
  end
end

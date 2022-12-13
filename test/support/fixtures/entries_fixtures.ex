defmodule Budget.EntriesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Budget.Entries` context.
  """

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
      |> Map.put_new_lazy(:category_id, fn -> category_fixture().id end)
      |> Enum.into(%{
        date: Timex.today() |> Date.to_iso8601(),
        description: "Entry description",
        value: 133
      })
      |> Budget.Entries.create_entry()

    entry
  end

  def recurrency_fixture(attrs \\ %{}) when is_map(attrs) do
    date = Map.get(attrs, :date, Timex.today() |> Date.to_iso8601())

    attrs = Map.put_new_lazy(attrs, :account_id, fn -> account_fixture().id end)
    attrs = Map.put_new_lazy(attrs, :category_id, fn -> category_fixture().id end)

    {:ok, entry} =
      attrs
      |> Enum.into(%{
        date: date,
        description: "Entry description",
        value: 133
      })
      |> Map.put(
        :recurrency_entry,
        attrs
        |> Map.get(:recurrency_entry, %{})
        |> Enum.into(%{
          original_date: date
        })
        |> Map.put(
          :recurrency,
          attrs
          |> Map.get(:recurrency_entry, %{})
          |> Map.get(:recurrency, %{})
          |> Enum.into(%{
            date_start: date,
            description: "Entry description",
            account_id: Map.get(attrs, :account_id),
            category_id: Map.get(attrs, :category_id),
            value: 133,
            is_forever: true,
            frequency: :monthly
          })
        )
      )
      |> Budget.Entries.create_entry()

    Budget.Entries.get_recurrency!(entry.recurrency_entry.recurrency_id)
  end
end

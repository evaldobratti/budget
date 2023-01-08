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
    any_originator =
      Enum.any?(attrs, fn {key, _} -> to_string(key) |> String.starts_with?("originator") end)

    attrs =
      if any_originator do
        attrs
      else
        attrs
        |> Map.put(:originator_regular, %{
          description: "Entry description",
          category_id: category_fixture().id
        })
      end

    {:ok, entry} =
      attrs
      |> Map.put_new_lazy(:account_id, fn -> account_fixture().id end)
      |> Enum.into(%{
        date: Timex.today() |> Date.to_iso8601(),
        value: 133
      })
      |> Budget.Entries.create_entry()

    entry
  end

  def recurrency_fixture(attrs \\ %{}) when is_map(attrs) do
    date = Map.get(attrs, :date, Timex.today() |> Date.to_iso8601())
    account_id = Map.get_lazy(attrs, :account_id, fn -> account_fixture().id end)
    value = Map.get(attrs, :value, 133)

    category_id =
      attrs
      |> Map.get(:originator_regular, %{})
      |> Map.get_lazy(:category_id, fn -> category_fixture().id end)

    description =
      attrs
      |> Map.get(:originator_regular, %{}) 
      |> Map.get(:description, "Entry description")

    {:ok, entry} =
      attrs
      |> Enum.into(%{
        date: date,
        value: value,
        account_id: account_id,
        is_recurrency: true,
        originator_regular: %{
          description: description,
          category_id: category_id
        }
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
            account_id: account_id,
            is_forever: true,
            frequency: :monthly,
          })
        )
      )
      |> Budget.Entries.create_entry()

    Budget.Entries.get_recurrency!(entry.recurrency_entry.recurrency_id)
  end
end

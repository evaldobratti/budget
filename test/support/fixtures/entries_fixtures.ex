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

  def entry_fixture(attrs) do
    {:ok, entry} =
      attrs
      |> Keyword.put_new_lazy(:account_id, fn -> account_fixture().id end)
      |> Enum.into(%{
        date: Timex.today() |> Date.to_iso8601(),
        description: "Entry description",
        value: 133
      })
      |> Budget.Entries.create_entry()

    entry
  end
end

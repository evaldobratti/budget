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
        name: "some name"
      })
      |> Budget.Entries.create_account()

    account
  end
end

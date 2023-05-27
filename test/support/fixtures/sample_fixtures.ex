defmodule Budget.SampleFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Budget.Sample` context.
  """

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        age: 42,
        name: "some name"
      })
      |> Budget.Sample.create_user()

    user
  end
end

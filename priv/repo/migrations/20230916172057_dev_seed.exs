defmodule Budget.Repo.Migrations.DevSeed do
  alias Budget.Transactions
  require Config
  use Ecto.Migration

  def up do
    if Application.get_env(:budget, :environment, %{}) |> Map.get(:name) == :dev do
      #
      # {:ok, acc1} = Transactions.create_account(%{
      #   initial_balance: -100,
      #   name: "Banco do Brasil"
      # })
      #
      # {:ok, acc2} = Transactions.create_account(%{
      #   initial_balance: -100,
      #   name: "CC NuBank"
      # })

    end
  end

  def down do
  end
end

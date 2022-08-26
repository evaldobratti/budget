defmodule Budget.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add :name, :string
      add :initial_balance, :decimal

      timestamps()
    end
  end
end

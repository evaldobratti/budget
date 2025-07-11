defmodule Budget.Repo.Migrations.CreatePartialBalances do
  use Ecto.Migration

  def change do
    create table(:partial_balances) do
      add :date, :date
      add :balance, :decimal
      add :account_id, references(:accounts, on_delete: :nothing)
      add :profile_id, references(:profiles, on_delete: :nothing)

      timestamps()
    end

    create index(:partial_balances, [:account_id])
    create index(:partial_balances, [:profile_id])
  end
end

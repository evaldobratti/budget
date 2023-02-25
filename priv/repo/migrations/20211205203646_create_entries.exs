defmodule Budget.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :date, :date
      add :description, :string
      add :is_carried_out, :boolean, default: false, null: false
      add :value, :decimal
      add :account_id, references(:accounts, on_delete: :nothing)

      timestamps()
    end

    create index(:transactions, [:account_id])
  end
end

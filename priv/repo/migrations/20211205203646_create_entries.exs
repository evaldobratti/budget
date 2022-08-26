defmodule Budget.Repo.Migrations.CreateEntries do
  use Ecto.Migration

  def change do
    create table(:entries) do
      add :date, :date
      add :description, :string
      add :is_carried_out, :boolean, default: false, null: false
      add :value, :decimal
      add :account_id, references(:accounts, on_delete: :nothing)

      timestamps()
    end

    create index(:entries, [:account_id])
  end
end

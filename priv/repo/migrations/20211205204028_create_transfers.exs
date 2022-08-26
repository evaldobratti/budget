defmodule Budget.Repo.Migrations.CreateTransfers do
  use Ecto.Migration

  def change do
    create table(:transfers) do
      add :entry_from_id, references(:entries, on_delete: :nothing)
      add :entry_to_id, references(:entries, on_delete: :nothing)

      timestamps()
    end

    create index(:transfers, [:entry_from_id])
    create index(:transfers, [:entry_to_id])
  end
end

defmodule Budget.Repo.Migrations.AddsEntryOriginDoRecurrencies do
  use Ecto.Migration

  def change do
    alter table(:recurrencies) do
      add :entry_origin_id, references(:entries, on_delete: :nothing)
    end

    create index(:recurrencies, [:entry_origin_id])
  end
end

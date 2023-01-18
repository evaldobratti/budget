defmodule Budget.Repo.Migrations.AddPositionToEntries do
  use Ecto.Migration

  def change do
    alter table(:entries) do
      add :position, :decimal
    end

    create index(:entries, [:position])
  end
end

defmodule Budget.Repo.Migrations.AddCategoryToEntries do
  use Ecto.Migration

  def change do
    alter table(:entries) do
      add :category_id, references(:categories, on_delete: :nothing)
    end

    create index(:entries, [:category_id])
  end
end

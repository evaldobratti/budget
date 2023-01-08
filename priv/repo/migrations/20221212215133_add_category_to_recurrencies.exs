defmodule Budget.Repo.Migrations.AddCategoryToRecurrencies do
  use Ecto.Migration

  def change do
    alter table(:recurrencies) do
      add :category_id, references(:categories, on_delete: :nothing)
    end

    create index(:recurrencies, [:category_id])
  end
end

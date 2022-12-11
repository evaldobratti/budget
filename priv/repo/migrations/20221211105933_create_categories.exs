defmodule Budget.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:categories) do
      add :name, :string
      add :path, {:array, :integer}, null: false

      timestamps()
    end

    create index(:categories, [:path])
  end
end

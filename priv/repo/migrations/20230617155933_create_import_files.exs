defmodule Budget.Repo.Migrations.CreateImportFiles do
  use Ecto.Migration

  def change do
    create table(:import_files) do
      add :name, :string
      add :hashes, {:array, :string}, null: false

      timestamps()
    end

    create index(:import_files, [:hashes])
  end
end

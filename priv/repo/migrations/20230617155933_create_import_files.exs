defmodule Budget.Repo.Migrations.CreateImportFiles do
  use Ecto.Migration

  def change do
    create table(:import_files) do
      add :path, :string
      add :state, :string
      add :hashes, {:array, :string}

      timestamps()
    end

    create index(:import_files, [:hashes])
  end
end

defmodule Budget.Repo.Migrations.CreateHintDescriptions do
  use Ecto.Migration

  def change do
    create table(:hint_descriptions) do
      add :original, :string
      add :transformed, :string

      timestamps()
    end

  end
end

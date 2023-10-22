defmodule Budget.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    drop_if_exists table(:users)

    create table(:users) do
      add :email, :string
      add :name, :string
      add :google_id, :string

      timestamps()
    end
  end
end

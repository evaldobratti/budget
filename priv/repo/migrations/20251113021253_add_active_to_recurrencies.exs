defmodule Budget.Repo.Migrations.AddActiveToRecurrencies do
  use Ecto.Migration

  def change do
    alter table(:recurrencies) do
      add :active, :boolean, default: true, null: false
    end

  end
end

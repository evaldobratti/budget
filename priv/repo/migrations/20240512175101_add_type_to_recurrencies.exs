defmodule Budget.Repo.Migrations.AddTypeToRecurrencies do
  use Ecto.Migration

  def change do
    alter table(:recurrencies) do
      add :type, :string, null: false, default: "until_date"
    end
  end
end

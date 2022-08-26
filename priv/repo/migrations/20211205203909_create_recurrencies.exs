defmodule Budget.Repo.Migrations.CreateRecurrencies do
  use Ecto.Migration

  def change do
    create table(:recurrencies) do
      add :is_forever, :boolean, default: false, null: false
      add :value, :decimal
      add :frequency, :string
      add :date_start, :date
      add :date_end, :date
      add :description, :string
      add :parcel_start, :integer
      add :parcel_end, :integer
      add :is_parcel, :boolean, default: false, null: false
      add :account_id, references(:accounts, on_delete: :nothing)

      timestamps()
    end

    create index(:recurrencies, [:account_id])
  end
end

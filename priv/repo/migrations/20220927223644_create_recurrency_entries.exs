defmodule Budget.Repo.Migrations.CreateRecurrencyEntries do
  use Ecto.Migration

  def change do
    create table(:recurrency_entries) do
      add :original_date, :date
      add :recurrency_id, references(:recurrencies, on_delete: :nothing)
      add :entry_id, references(:entries, on_delete: :nothing)
      add :parcel, :int
      add :parcel_end, :int

      timestamps()
    end

    create index(:recurrency_entries, [:recurrency_id])
    create index(:recurrency_entries, [:entry_id])
  end
end

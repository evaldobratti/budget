defmodule Budget.Repo.Migrations.CreateRecurrencyTransactions do
  use Ecto.Migration

  def change do
    create table(:recurrency_transactions) do
      add :original_date, :date
      add :recurrency_id, references(:recurrencies, on_delete: :nothing)
      add :transaction_id, references(:transactions, on_delete: :nothing)
      add :parcel, :int
      add :parcel_end, :int

      timestamps()
    end

    create index(:recurrency_transactions, [:recurrency_id])
    create index(:recurrency_transactions, [:transaction_id])
  end
end

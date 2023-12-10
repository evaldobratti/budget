defmodule Budget.Repo.Migrations.AddsTransactionsPaid do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add :paid, :boolean, null: false, default: true
    end
  end
end

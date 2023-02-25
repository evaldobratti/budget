defmodule Budget.Repo.Migrations.AddPositionToTransactions do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add :position, :decimal
    end

    create index(:transactions, [:position])
  end
end

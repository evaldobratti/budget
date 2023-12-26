defmodule Budget.Repo.Migrations.AddOriginators do
  use Ecto.Migration

  def change do
    create table(:originators_regular) do
      add :description, :string
      add :category_id, references(:categories, on_delete: :nothing)

      timestamps()
    end

    create index(:originators_regular, [:category_id])

    create table(:originators_transfer) do
      timestamps()
    end

    alter table(:transactions) do
      add :originator_regular_id, references(:originators_regular, on_delete: :nothing)
      add :originator_transfer_part_id, references(:originators_transfer, on_delete: :nothing)

      add :originator_transfer_counter_part_id,
          references(:originators_transfer, on_delete: :nothing)

      remove_if_exists :description, :string
    end

    alter table(:recurrencies) do
      remove_if_exists :description, :string
      remove_if_exists :value, :decimal

      add :transaction_payload, :map
    end

    create index(:transactions, [:originator_regular_id])
  end
end

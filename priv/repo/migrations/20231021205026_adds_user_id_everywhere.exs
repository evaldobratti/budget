defmodule Budget.Repo.Migrations.AddsUserIdEverywhere do
  use Ecto.Migration

  def change do
    tables = [
      :transactions, 
      :categories,
      :originators_regular,
      :originators_transfer,
      :recurrencies,
      :recurrency_transactions,
      :accounts,
      :hint_descriptions,
      :import_files,
    ]

    for table_name <- tables do
      alter table(table_name) do
        add :user_id, references(:users, on_delete: :nothing), null: false
      end

      create index(table_name, [:user_id])
    end

  end
end

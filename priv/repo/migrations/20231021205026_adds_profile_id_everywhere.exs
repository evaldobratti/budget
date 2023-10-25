defmodule Budget.Repo.Migrations.AddsProfileIdEverywhere do
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
        add :profile_id, references(:profiles, on_delete: :nothing), null: false
      end

      create index(table_name, [:profile_id])
    end

  end
end

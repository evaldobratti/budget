defmodule Budget.Repo.Migrations.DropIsForeverIsParcelFromRecurrencies do
  use Ecto.Migration

  def change do
    alter table(:recurrencies) do
      remove_if_exists :is_parcel, :boolean
      remove_if_exists :is_forever, :boolean
    end

  end
end

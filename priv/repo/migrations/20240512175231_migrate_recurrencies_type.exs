defmodule Budget.Repo.Migrations.MigrateRecurrenciesType do
  alias Budget.Transactions.Recurrency

  import Ecto.Query
  use Ecto.Migration

  def up do
    Budget.Repo.update_all(from(r in Recurrency, where: fragment("is_parcel = ?", true)), [set: [type: :parcel]], skip_profile_id: true)
    Budget.Repo.update_all(from(r in Recurrency, where: fragment("is_forever = ?", true)), [set: [type: :forever]], skip_profile_id: true)
  end

  def down do
  end
end

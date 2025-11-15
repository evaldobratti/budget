defmodule Budget.Repo.Migrations.MigrateRecurrenciesActive do
  alias Budget.Transactions
  alias Budget.Transactions.Recurrency
  use Ecto.Migration

  require Logger

  import Ecto.Query

  def change do
    profiles = Budget.Repo.all(
      from(r in Recurrency, distinct: r.profile_id, select: r.profile_id),
      skip_profile_id: true
    )


    profiles
    |> Enum.each(fn profile_id ->
      Budget.Repo.put_profile_id(profile_id)

      result = 
        Transactions.find_recurrencies()
        |> Enum.map(&Transactions.check_recurrency_active(&1.id))
        |> Enum.map(fn {:ok, r} -> {r.id, r.active} end)

      active = result |> Enum.filter(fn {_, active} -> active end) |> length
      not_active = length(result) - active

      
      Logger.info("updated profile_id:#{profile_id} active:#{active} not_active:#{not_active} #{inspect(result)}")
    end)  
  end
end

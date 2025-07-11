defmodule Mix.Tasks.PartialBalanceCheck do
  alias Budget.Transactions.Account
  alias Budget.Transactions.PartialBalance
  alias Budget.Transactions
  import Ecto.Query
  use Mix.Task

  @requirements ["app.start"]

  @impl true
  def run(_args) do
    Budget.Repo.put_profile_id(1)

    # from(Account) |> Budget.Repo.all() |> length |> IO.inspect()

    # from(PartialBalance) |> Budget.Repo.delete_all()
    #
    Transactions.update_partial_balances()
    #
    # max_date(~D[2022-09-01])
    # |> Enum.filter(fn {_, {comparison, _, _}} -> !comparison end)
    # |> case do
    #   [] -> IO.inspect("all good!")
    #   other -> IO.inspect(["ouch", other], limit: :infinity)
    # end
  end

  def max_date(current_date) do
    if current_date == ~D[2025-01-31] do
      []
    else
      previous = Transactions.previous_balance_at(current_date)
      current = Transactions.balance_at(current_date)

      [
        {current_date, {previous == current, previous, current}}
        | max_date(Timex.shift(current_date, days: 1))
      ]
    end
  end
end

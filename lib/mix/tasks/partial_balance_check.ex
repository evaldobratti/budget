defmodule Mix.Tasks.PartialBalanceCheck do
  alias Budget.Transactions
  use Mix.Task

  @requirements ["app.start"]

  @impl true
  def run(args) do
    Budget.Repo.put_profile_id(1)

    Transactions.update_partial_balances()

    max_date(~D[2024-09-01])
    |> Enum.filter(fn {_, {comparison, _}} -> !comparison end)
    |> case do
      [] -> IO.inspect("all good!")
      other -> IO.inspect(["ouch", other], limit: :infinity)
    end
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

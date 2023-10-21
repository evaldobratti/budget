defmodule Budget.Reports do

  import Ecto.Query
  alias Budget.Transactions
  alias Budget.Transactions.Transaction
  alias Budget.Repo

  def expenses(%{date_start: date_start, date_end: date_end} = params) do
    Transactions.transactions_in_period([], date_start, date_end)
    |> Enum.filter(& Decimal.negative?(&1.value))
    |> Enum.map(& %{ &1 | value: Decimal.negate(&1.value)})
    |> default_group_by(params)
  end

  def incomes(%{date_start: date_start, date_end: date_end} = params) do
    Transactions.transactions_in_period([], date_start, date_end)
    |> Enum.filter(& Decimal.positive?(&1.value))
    |> default_group_by(params)
  end

  defp default_group_by(transactions, params) do
    date_start = params.date_start |> Timex.beginning_of_month()
    date_end = params.date_end

    months = months_until(date_start, date_end)

    transactions
    |> Enum.filter(& &1.originator_regular)
    |> Enum.group_by(& %{id: &1.originator_regular.category.id, name: &1.originator_regular.category.name})
    |> Enum.map(fn {key, value} -> %{category: key, grouped: Enum.group_by(value, & Timex.beginning_of_month(&1.date))} end)
    |> Enum.map(fn 
      %{category: category, grouped: grouped} -> 
        values = 
          months
          |> Enum.map(fn date ->
            transactions = Map.get(grouped, date, []) 

            {
              date, 
              transactions 
              |> Enum.map(& &1.value) 
              |> Enum.reduce(Decimal.new(0), & Decimal.add(&1, &2)) 
            }

          end)

        %{
          category: category,
          values: Enum.into(values, %{}),
        }
      end)

  end

  def months_until(date, date_end) do
    if Timex.before?(date, date_end) do
      [date] ++ months_until(Timex.shift(date, months: 1), date_end)
    else
      []
    end
  end


  
end

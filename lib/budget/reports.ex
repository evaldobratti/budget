defmodule Budget.Reports do
  alias Budget.Transactions




  def expenses(%{date_start: date_start, date_end: date_end} = params) do
    Transactions.transactions_in_period(date_start, date_end)
    |> Enum.filter(&Decimal.negative?(&1.value))
    |> Enum.map(&%{&1 | value: Decimal.negate(&1.value)})
    |> default_group_by(params)
  end

  def incomes(%{date_start: date_start, date_end: date_end} = params) do
    Transactions.transactions_in_period(date_start, date_end)
    |> Enum.filter(&Decimal.positive?(&1.value))
    |> default_group_by(params)
  end

  defp default_group_by(transactions, params) do
    date_start = params.date_start |> Timex.beginning_of_month()
    date_end = params.date_end

    transactions
    |> Enum.filter(& &1.originator_regular)
    |> Enum.group_by(
      &Timex.beginning_of_month(&1.date)
    )
    |> Enum.map(fn {month, transactions} ->
      %{month: month, grouped: Enum.group_by(transactions, &"#{&1.originator_regular.category.id} - #{&1.originator_regular.category.name}") }
    end)
    |> Enum.map(fn
      %{month: month, grouped: grouped} ->
        values =
          grouped
          |> Enum.map(fn {category, transactions } ->
            {
              category,
              transactions
              |> Enum.map(& &1.value)
              |> Enum.reduce(Decimal.new(0), &Decimal.add(&1, &2))
            }
          end)

        %{
          month: month,
          values: Enum.into(values, %{})
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

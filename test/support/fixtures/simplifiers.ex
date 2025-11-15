defmodule Budget.Simplifiers do
  alias Budget.Transactions.Transaction

  def simplify(%Transaction{} = transaction) do
    originator =
      case transaction do
        %{originator_regular_id: id} when is_integer(id) ->
          %{
            description: transaction.originator_regular.description,
            category_id: transaction.originator_regular.category_id
          }

        %{originator_transfer_part_id: id} when is_integer(id) ->
          %{
            date: transaction.originator_transfer_part.counter_part.date,
            other_account_id: transaction.originator_transfer_part.counter_part.account_id,
            other_value:
              transaction.originator_transfer_part.counter_part.value |> Decimal.to_float()
          }

        %{originator_transfer_counter_part_id: id} when is_integer(id) ->
          %{
            date: transaction.originator_transfer_counter_part.part.date,
            other_account_id: transaction.originator_transfer_counter_part.part.account_id,
            other_value:
              transaction.originator_transfer_counter_part.part.value |> Decimal.to_float()
          }
      end

    recurrency_data =
      case transaction.recurrency_transaction do
        %Ecto.Association.NotLoaded{} ->
          %{}

        nil ->
          %{}

        _ ->
          recurrency = transaction.recurrency_transaction.recurrency

          %{
            recurrency_transaction: %{
              original_date: transaction.recurrency_transaction.original_date,
              parcel: transaction.recurrency_transaction.parcel,
              parcel_end: transaction.recurrency_transaction.parcel_end
            },
            recurrency: %{
              frequency: recurrency.frequency,
              date_start: recurrency.date_start,
              date_end: recurrency.date_end,
              transaction_payload: recurrency.transaction_payload,
              type: recurrency.type,
              parcel_start: recurrency.parcel_start,
              parcel_end: recurrency.parcel_end
            }
          }
      end

    %{
      date: transaction.date,
      account_id: transaction.account_id,
      originator: originator,
      value: Decimal.to_float(transaction.value),
      paid: transaction.paid
    }
    |> Map.merge(recurrency_data)
  end

  def simplify({:ok, %Transaction{} = transaction}) do
    {:ok, simplify(transaction)}
  end

  def persist(%{id: "recurrency-" <> _ } = transaction) do
    {:ok, _} = Transaction.Form.apply_update(transaction, %{})
  end
end

defmodule Budget.Entries.Originator.Transfer do
  use Ecto.Schema

  import Ecto.Query
  alias Budget.Entries
  alias Budget.Entries.Entry

  schema "originators_transfer" do
    has_one(:part, Entry, foreign_key: :originator_transfer_part_id)
    has_one(:counter_part, Entry, foreign_key: :originator_transfer_counter_part_id)

    field(:other_account_id, :integer, virtual: true)

    timestamps()
  end

  @behaviour Budget.Entries.Originator

  def restore_for_recurrency(payload) do
    account =
      payload
      |> Map.get("part_account_id")
      |> Entries.get_account!()

    other_account =
      payload
      |> Map.get("counter_part_account_id")
      |> Entries.get_account!()

    %{
      originator_transfer_part: %__MODULE__{
        counter_part: %Entry{
          value: Decimal.new(Map.get(payload, "value")) |> Decimal.negate(),
          account_id: other_account.id,
          account: other_account,
          is_carried_out: false,
          position: 1
        }
      },
      account_id: account.id,
      account: account,
      value: Decimal.new(Map.get(payload, "value"))
    }
  end

  def get_recurrency_payload(transaction) do
    {part_account_id, counter_part_account_id} =
      if transaction.originator_transfer_part_id do
        {
          transaction.account_id,
          transaction.originator_transfer_part.counter_part.account_id
        }
      else
        {
          transaction.originator_transfer_counter_part.part.account_id,
          transaction.account_id
        }
      end

    %{
      part_account_id: part_account_id,
      counter_part_account_id: counter_part_account_id,
      value: transaction.value,
      originator: __MODULE__
    }
  end

  def build_entries(recurrency_params, params) do
    part_params = %{
      originator_transfer_part: %__MODULE__{
        counter_part: %Entry{
          date: recurrency_params.date,
          value: params.originator_transfer_part.counter_part.value,
          account_id: params.originator_transfer_part.counter_part.account_id,
          account: params.originator_transfer_part.counter_part.account,
          is_carried_out: false,
          position: Decimal.new(1),
          recurrency_entry: recurrency_params.recurrency_entry
        }
      },
      date: recurrency_params.date,
      account_id: params.account_id,
      account: params.account,
      is_carried_out: false,
      position: Decimal.new(1),
      recurrency_entry: recurrency_params.recurrency_entry,
      value: params.value,
      id: recurrency_params.id <> "-0"
    }

    counter_params = %{
      originator_transfer_counter_part: %__MODULE__{
        part: %Entry{
          date: recurrency_params.date,
          value: params.value,
          account_id: params.account_id,
          account: params.account,
          is_carried_out: false,
          recurrency_entry: recurrency_params.recurrency_entry,
          position: Decimal.new(1)
        }
      },
      date: recurrency_params.date,
      account_id: params.originator_transfer_part.counter_part.account_id,
      account: params.originator_transfer_part.counter_part.account,
      is_carried_out: false,
      position: Decimal.new(1),
      recurrency_entry: recurrency_params.recurrency_entry,
      value: params.originator_transfer_part.counter_part.value,
      id: recurrency_params.id <> "-1"
    }

    [
      %Budget.Entries.Entry{}
      |> Map.merge(recurrency_params)
      |> Map.merge(part_params)
      |> Map.put(:originator_regular, nil),
      %Budget.Entries.Entry{}
      |> Map.merge(recurrency_params)
      |> Map.merge(counter_params)
      |> Map.put(:originator_regular, nil)
    ]
  end

  def delete(transaction_ids) do
    transfer_ids = from(
      transaction in Entry, 
      where: transaction.id in ^transaction_ids, 
      select: coalesce(transaction.originator_transfer_part_id, transaction.originator_transfer_counter_part_id)
    )

    part_counter_part_ids = from(
      transaction in Entry,
      where: transaction.originator_transfer_part_id in subquery(transfer_ids) or transaction.originator_transfer_counter_part_id in subquery(transfer_ids),
      select: transaction.id
    )

    fn _ ->
      Ecto.Multi.new()
      |> Ecto.Multi.all(:transactions, part_counter_part_ids)
      |> Ecto.Multi.all(:originators, transfer_ids)
    end
  end
end

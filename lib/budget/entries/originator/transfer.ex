defmodule Budget.Entries.Originator.Transfer do
  use Ecto.Schema

  import Ecto.Changeset

  alias Budget.Entries.Entry

  schema "originators_transfer" do
    has_one :part, Entry, foreign_key: :originator_transfer_part_id
    has_one :counter_part, Entry, foreign_key: :originator_transfer_counter_part_id

    field :other_account_id, :integer, virtual: true

    timestamps()
  end

  def create_other_part(entry_changeset, transfer_map, field) do
    %__MODULE__{}
    |> change()
    |> put_assoc(
      field, 
      %Entry{}
      |> change(%{
        date: get_field(entry_changeset, :date),
        value: get_field(entry_changeset, :value) |> Decimal.negate(),
        account_id: Map.get(transfer_map, :other_account_id),
        is_carried_out: get_field(entry_changeset, :is_carried_out),
        position: get_field(entry_changeset, :position) |> Decimal.add(Decimal.new(1))
      })
    )
  end

  def update_other_part(entry_changeset, transaction_field, transfer_field) do
    transfer_changeset =
      get_field(entry_changeset, transaction_field)
      |> change()

    other_part_changeset = 
      get_field(transfer_changeset, transfer_field) 
      |> change(%{value: get_change(entry_changeset, :value) |> Decimal.negate()})

    put_assoc(transfer_changeset, transfer_field, other_part_changeset)
  end

  @behaviour Budget.Entries.Originator

  def restore_for_recurrency(payload) do
    account_id = 
      payload
      |> Map.get("part_account_id")

    other_account_id = 
      payload
      |> Map.get("counter_part_account_id")

    %{
      originator_transfer_part: %__MODULE__{
        counter_part: %Entry{
          value: Decimal.new(Map.get(payload, "value")) |> Decimal.negate(),
          account_id: other_account_id,
          is_carried_out: false,
          position: 1
        }
      },
      account_id: account_id,
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
    part_params =
      %{
        originator_transfer_counter_part: %__MODULE__{
          part: %Entry{
            date: recurrency_params.date,
            value: params.originator_transfer_part.counter_part.value,
            account_id: params.originator_transfer_part.counter_part.account_id,
            is_carried_out: false,
            position: Decimal.new(1),
            recurrency_entry: recurrency_params.recurrency_entry
          }
        },
        date: recurrency_params.date,
        account_id: params.account_id,
        is_carried_out: false,
        position: Decimal.new(1),
        recurrency_entry: recurrency_params.recurrency_entry,
        value: params.value
      }

    counter_params = 
      %{
        originator_transfer_counter_part: %__MODULE__{
          part: %Entry{
            date: recurrency_params.date,
            value: params.value,
            account_id: params.account_id,
            is_carried_out: false,
            recurrency_entry: recurrency_params.recurrency_entry,
            position: Decimal.new(1)
          }
        },
        date: recurrency_params.date,
        account_id: params.originator_transfer_part.counter_part.account_id,
        is_carried_out: false,
        position: Decimal.new(1),
        recurrency_entry: recurrency_params.recurrency_entry,
        value: params.originator_transfer_part.counter_part.value
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
end

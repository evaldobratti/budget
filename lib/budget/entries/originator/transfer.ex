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

  def restore_for_recurrency(%{"originator_transfer_part" => transfer_part} = payload) do
    other_account_id = 
      transfer_part
      |> Map.get("account_id")

    %{
      originator_transfer_part: %__MODULE__{
        counter_part: %Entry{
          date: Timex.today(),
          value: Decimal.new(Map.get(payload, "value")) |> Decimal.negate(),
          account_id: other_account_id,
          is_carried_out: false,
          position: 1
        }
      },
      value: Decimal.new(Map.get(payload, "value"))
    }
  end

  def get_recurrency_payload(entry_changeset) do
    account_id =
      entry_changeset
      |> get_field(:originator_transfer_part)
      |> Map.get(:counter_part)
      |> Map.get(:account_id)

    %{
      originator_transfer_part: %{
        account_id: account_id
      },
      value: get_field(entry_changeset, :value)
    }
  end
  
end

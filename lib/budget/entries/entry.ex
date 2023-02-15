defmodule Budget.Entries.Entry do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Budget.Entries.Recurrency
  alias Ecto.Changeset
  alias Budget.Entries.Account
  alias Budget.Entries.RecurrencyEntry
  alias Budget.Entries.Originator.Transfer
  alias Budget.Entries.Originator.Regular

  schema "entries" do
    field(:date, :date)
    field(:is_carried_out, :boolean, default: false)
    field(:value, :decimal)
    field(:position, :decimal)

    belongs_to(:account, Account)

    belongs_to(:originator_regular, Regular, on_replace: :update)
    belongs_to(:originator_transfer_part, Transfer)
    belongs_to(:originator_transfer_counter_part, Transfer)

    field(:originator_transfer, :map, virtual: true)
    field(:is_recurrency, :boolean, virtual: true)
    field(:is_transfer, :boolean, virtual: true)
    field(:recurrency_apply_forward, :boolean, virtual: true)

    has_one(:recurrency_entry, RecurrencyEntry)

    timestamps()
  end
end

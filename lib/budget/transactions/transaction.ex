defmodule Budget.Transactions.Transaction do
  use Ecto.Schema

  alias Budget.Transactions.Account
  alias Budget.Transactions.RecurrencyTransaction
  alias Budget.Transactions.Originator.Transfer
  alias Budget.Transactions.Originator.Regular

  schema "transactions" do
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

    has_one(:recurrency_transaction, RecurrencyTransaction)

    timestamps()
  end
end

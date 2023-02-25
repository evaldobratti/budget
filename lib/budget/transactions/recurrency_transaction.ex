defmodule Budget.Transactions.RecurrencyTransaction do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.Transactions.Transaction
  alias Budget.Transactions.Recurrency

  schema "recurrency_transactions" do
    field :original_date, :date
    field :parcel, :integer
    field :parcel_end, :integer

    belongs_to :recurrency, Recurrency
    belongs_to :transaction, Transaction

    timestamps()
  end
end

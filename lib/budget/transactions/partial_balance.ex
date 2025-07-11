defmodule Budget.Transactions.PartialBalance do
  use Ecto.Schema

  alias Budget.Transactions.Account

  import Ecto.Changeset

  schema "partial_balances" do
    field :date, :date
    field :balance, :decimal
    field :profile_id, :integer
    belongs_to :account, Account

    timestamps()
  end

  def changeset(partial_balance, attrs) do
    partial_balance
    |> cast(attrs, [:date, :balance, :account_id])
    |> validate_required([:date, :balance, :account_id])
    |> Budget.Repo.add_profile_id()
  end
end

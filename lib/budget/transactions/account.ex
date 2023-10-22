defmodule Budget.Transactions.Account do
  use Ecto.Schema
  import Ecto.Changeset

  schema "accounts" do
    field :initial_balance, :decimal
    field :name, :string
    field :user_id, :integer

    timestamps()
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:name, :initial_balance])
    |> validate_required([:name, :initial_balance])
    |> Budget.Repo.add_user_id()
  end
end

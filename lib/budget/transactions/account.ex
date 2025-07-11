defmodule Budget.Transactions.Account do
  use Ecto.Schema
  import Ecto.Changeset

  schema "accounts" do
    field :initial_balance, :decimal
    field :name, :string
    field :profile_id, :integer

    timestamps()
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:name, :initial_balance, :inserted_at])
    |> validate_required([:name, :initial_balance])
    |> Budget.Repo.add_profile_id()
  end
end

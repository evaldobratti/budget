defmodule Budget.Entries.Transfer do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transfers" do
    field :entry_from_id, :id
    field :entry_to_id, :id

    timestamps()
  end

  @doc false
  def changeset(transfer, attrs) do
    transfer
    |> cast(attrs, [])
    |> validate_required([])
  end
end

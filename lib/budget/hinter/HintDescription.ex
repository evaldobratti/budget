defmodule Budget.Hinter.HintDescription do
  use Ecto.Schema
  import Ecto.Changeset

  schema "hint_descriptions" do
    field :original, :string
    field :transformed, :string

    timestamps()
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:original, :transformed])
    |> validate_required([:original, :transformed])
  end
end

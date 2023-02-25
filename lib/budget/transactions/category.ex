defmodule Budget.Transactions.Category do
  use Ecto.Schema
  import Ecto.Changeset

  use EctoMaterializedPath

  schema "categories" do
    field :name, :string
    field :path, EctoMaterializedPath.Path, default: []

    timestamps()
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :path])
    |> validate_required(:name)
  end
end

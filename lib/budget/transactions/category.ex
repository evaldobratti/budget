defmodule Budget.Transactions.Category do
  use Ecto.Schema
  import Ecto.Changeset
  

  use EctoMaterializedPath

  schema "categories" do
    field :name, :string
    field :path, EctoMaterializedPath.Path, default: []
    field :user_id, :integer

    field :transactions_count, :integer, virtual: true

    timestamps()
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :path])
    |> validate_required(:name)
    |> Budget.Repo.add_user_id()
  end
end

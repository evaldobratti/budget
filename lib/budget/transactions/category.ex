defmodule Budget.Transactions.Category do
  use Ecto.Schema
  import Ecto.Changeset

  use EctoMaterializedPath

  schema "categories" do
    field :name, :string
    field :path, EctoMaterializedPath.Path, default: []
    field :profile_id, :integer

    field :transactions_count, :integer, virtual: true

    timestamps()
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :path])
    |> validate_required(:name)
    |> Budget.Repo.add_profile_id()
  end

  def get_subtree_ids({category, []}), do: [category.id]
  def get_subtree_ids({category, children}), do: [category.id] ++ Enum.flat_map(children, &get_subtree_ids/1)

  def find_in_tree([], _id), do: nil
  def find_in_tree([{category, children} | tail], id) do
    if category.id == id do
      {category, children}
    else
      found = find_in_tree(children, id)

      if found, do: found, else: find_in_tree(tail, id)
    end
  end

end


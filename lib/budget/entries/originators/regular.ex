defmodule Budget.Entries.Originators.Regular do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.Entries.Category

  schema "originators_regular" do
    field :description, :string
    belongs_to :category, Category

    timestamps()
  end

  def changeset(regular, attrs) do
    regular
    |> cast(attrs, [:description, :category_id])
    |> validate_required([:description, :category_id])
  end
end

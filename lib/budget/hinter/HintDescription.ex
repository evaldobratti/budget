defmodule Budget.Hinter.HintDescription do
  use Ecto.Schema
  import Ecto.Changeset

  schema "hint_descriptions" do
    field :original, :string
    field :transformed, :string
    field :profile_id, :integer

    timestamps()
  end

  @doc false
  def changeset(hint_description, attrs) do
    hint_description 
    |> cast(attrs, [:original, :transformed])
    |> validate_required([:original, :transformed])
    |> Budget.Repo.add_profile_id()
  end
end

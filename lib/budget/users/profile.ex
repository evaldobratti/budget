defmodule Budget.Users.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.Users.User

  schema "profiles" do
    belongs_to :user, User
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :user_id])
    |> validate_required([:name])
  end
end

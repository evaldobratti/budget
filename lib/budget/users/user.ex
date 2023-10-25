defmodule Budget.Users.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.Users.Profile

  schema "users" do
    field :email, :string
    field :google_id, :string
    field :name, :string

    has_many :profiles, Profile

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :google_id])
    |> validate_required([:email, :name, :google_id])
    |> cast_assoc(:profiles)
  end
end

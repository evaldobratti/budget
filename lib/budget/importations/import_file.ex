defmodule Budget.Importations.ImportFile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "import_files" do
    field :name, :string
    field :hashes, {:array, :string}

    timestamps()
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:name, :hashes])
    |> validate_required([:name, :hashes])
  end
end


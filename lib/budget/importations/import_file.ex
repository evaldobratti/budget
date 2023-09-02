defmodule Budget.Importations.ImportFile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "import_files" do
    field :path, :string
    field :state, :string, default: "new"
    field :hashes, {:array, :string}

    timestamps()
  end

  @doc false
  def changeset(import_file, attrs) do
    import_file
    |> cast(attrs, [:path, :state, :hashes])
    |> validate_required([:path, :state])
  end
end


defmodule Budget.Importations do
  alias Budget.Importations.ImportFile
  alias Budget.Repo

  import Ecto.Query

  def create_import_file(path) do
    Budget.Repo.insert(
      ImportFile.changeset(%ImportFile{}, %{
        path: path,
        state: "new"
      })
    )
  end

  def get_import_file!(id), do: Repo.get!(ImportFile, id)

  def insert(import_file, changesets) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:inserts, fn _repo, _changes ->
      {:ok, Enum.map(changesets, &Budget.Transactions.Transaction.Form.apply_insert(&1))}
    end)
    |> Ecto.Multi.update(
      :import_file,
      ImportFile.changeset(
        import_file,
        %{
          state: "imported",
          hashes: changesets |> Enum.map(& &1.params["hash"])
        }
      )
    )
    |> Budget.Repo.transaction()
  end

  def list_import_files do
    Repo.all(from(f in ImportFile, order_by: [desc: f.inserted_at]))
  end

  def has_conflict?(hash) do
    Repo.exists?(
      from(
        f in ImportFile,
        where: ^hash in f.hashes
      )
    )
  end
end

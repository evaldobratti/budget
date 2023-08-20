defmodule Budget.Importations do

  alias Budget.Importations.ImportFile
  alias Budget.Repo

  import Ecto.Query

  def import(file) do
    key = Path.basename(file)

    name = Budget.Importations.Worker.name(key)

    DynamicSupervisor.start_child(Budget.Importer, {Budget.Importations.Worker, %{
      file: file,
      name: name
    }})

    {:ok, key}
  end

  def find_process(file) do
    Budget.Importations.Worker.whereis(file)
  end

  def insert(changesets, file_data) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:inserts, fn _repo, _changes ->
      {:ok, Enum.map(changesets, &Budget.Transactions.Transaction.Form.apply_insert(&1))}
    end)
    |> Ecto.Multi.insert(:import_file, %ImportFile{
      name: file_data.name, 
      hashes: changesets |> Enum.map(& &1.params["hash"])
    })
    |> Budget.Repo.transaction()
  end

  def list_import_files do
    Repo.all(from(f in ImportFile, order_by: f.name))
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

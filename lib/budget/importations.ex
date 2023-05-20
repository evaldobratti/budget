defmodule Budget.Importations do

  def import(file) do
    key = Path.basename(file)

    name = Budget.Importations.Worker.name(key)

    DynamicSupervisor.start_child(Budget.Importer, {Budget.Importations.Worker, %{
      file: key,
      name: name
    }})

    {:ok, key}
  end

  def find_process(file) do
    Budget.Importations.Worker.whereis(file)
  end

  def insert(changesets) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:inserts, fn _repo, _changes ->
      {:ok, Enum.map(changesets, &Budget.Transactions.Transaction.Form.apply_insert(&1))}
    end)
    |> Budget.Repo.transaction()
  end
end

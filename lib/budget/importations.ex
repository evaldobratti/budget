defmodule Budget.Importations do

  def import(file) do
    ref = 
      make_ref()
      |> inspect

    digits = Regex.scan(~r/\d/, ref) |> List.flatten() |> Enum.join("")

    name = Budget.Importations.Worker.name(digits)

    DynamicSupervisor.start_child(Budget.Importer, {Budget.Importations.Worker, %{
      file: file,
      name: name
    }})

    {:ok, digits}
  end

  def find_process(digits) do
    Budget.Importations.Worker.whereis(digits)
  end
end

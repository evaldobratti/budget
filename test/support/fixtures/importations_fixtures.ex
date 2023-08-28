defmodule Budget.ImportationsFixtures do

  alias Budget.Importations

  def import_file_fixture(:simple) do
    {:ok, file} = Importations.create_import_file("test/budget/importations/files/credit_card/nu_bank/simple.txt")

    file
  end
end

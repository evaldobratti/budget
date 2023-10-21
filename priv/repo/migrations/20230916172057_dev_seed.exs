defmodule Budget.Repo.Migrations.DevSeed do
  alias Budget.Transactions

  use Ecto.Migration

  def up do
    if Application.get_env(:budget, :environment, %{}) |> Map.get(:name) == :dev do

      {:ok, acc_bb} = Transactions.create_account(%{
        initial_balance: -100,
        name: "Banco do Brasil"
      })

      {:ok, acc_nu} = Transactions.create_account(%{
        initial_balance: -100,
        name: "CC NuBank"
      })

      {:ok, c_alimentacao} = Transactions.create_category(%{name: "Alimentação"})
      {:ok, c_mercado} = Transactions.create_category(%{name: "Mercado"})
      {:ok, c_lazer} = Transactions.create_category(%{name: "Lazer"})
      {:ok, c_receita} = Transactions.create_category(%{name: "Receitas"})
      {:ok, c_saude} = Transactions.create_category(%{name: "Saúde"})
      {:ok, c_farmacia} = Transactions.create_category(%{name: "Farmácia"}, c_saude)
      {:ok, c_consultas} = Transactions.create_category(%{name: "Consultas"}, c_saude)
      {:ok, c_moradia} = Transactions.create_category(%{name: "Moradia"})
      {:ok, c_transporte} = Transactions.create_category(%{name: "Transporte"})
      {:ok, c_impostos} = Transactions.create_category(%{name: "Impostos"})
      {:ok, c_vestuario} = Transactions.create_category(%{name: "Vestuário"})
      {:ok, c_presentes} = Transactions.create_category(%{name: "Presentes"})
      {:ok, c_viagem} = Transactions.create_category(%{name: "Viagem"})
      {:ok, c_mensalidades} = Transactions.create_category(%{name: "Mensalidades"})
      {:ok, c_educacao} = Transactions.create_category(%{name: "Educação"})

      month_first = Timex.beginning_of_month(Timex.today())
      month_fifth = Timex.shift(month_first, days: 5)

      [
        %{date: month_fifth, originator: "regular", regular: %{description: "Salário", category_id: c_receita.id}, account_id: acc_bb.id, value: 3000, recurrency: %{is_forever: true, frequency: :monthly}},

        %{date: month_fifth, originator: "regular", regular: %{description: "Aluguel", category_id: c_moradia.id}, account_id: acc_bb.id, value: -600, recurrency: %{is_forever: true, frequency: :monthly}},
        %{date: month_fifth, originator: "regular", regular: %{description: "Eletricidade", category_id: c_moradia.id}, account_id: acc_bb.id, value: -150, recurrency: %{is_forever: true, frequency: :monthly}},
        %{date: month_fifth, originator: "regular", regular: %{description: "Internet", category_id: c_moradia.id}, account_id: acc_bb.id, value: -100, recurrency: %{is_forever: true, frequency: :monthly}},

        %{date: month_fifth, originator: "regular", regular: %{description: "Imposto", category_id: c_impostos.id}, account_id: acc_bb.id, value: -100, recurrency: %{is_forever: true, frequency: :monthly}},

        %{date: Timex.shift(month_first, days: 11), originator: "regular", regular: %{description: "Bar", category_id: c_lazer.id}, account_id: acc_nu.id, value: -79},
        %{date: Timex.shift(month_first, days: 11), originator: "regular", regular: %{description: "Mercado", category_id: c_mercado.id}, account_id: acc_nu.id, value: -130},

        %{date: Timex.shift(month_first, days: 14), originator: "regular", regular: %{description: "Mercado", category_id: c_mercado.id}, account_id: acc_nu.id, value: -102},

        %{date: Timex.shift(month_first, days: 15), originator: "regular", regular: %{description: "Combustível", category_id: c_transporte.id}, account_id: acc_nu.id, value: -220},

        %{date: Timex.shift(month_first, days: 15), originator: "regular", regular: %{description: "Calça", category_id: c_vestuario.id}, account_id: acc_nu.id, value: -100},

        %{date: Timex.shift(month_first, days: 16), originator: "regular", regular: %{description: "Tênis", category_id: c_vestuario.id}, account_id: acc_nu.id, value: -100, recurrency: %{is_parcel: true, frequency: :monthly, parcel_start: 1, parcel_end: 4}},

        %{date: Timex.shift(month_first, days: 22), originator: "regular", regular: %{description: "Combustível", category_id: c_viagem.id}, account_id: acc_nu.id, value: -200},
        %{date: Timex.shift(month_first, days: 22), originator: "regular", regular: %{description: "Restaurante", category_id: c_viagem.id}, account_id: acc_nu.id, value: -55},

        %{date: Timex.shift(month_first, days: 24), originator: "regular", regular: %{description: "Alergologista", category_id: c_consultas.id}, account_id: acc_bb.id, value: -200},
        %{date: Timex.shift(month_first, days: 24), originator: "regular", regular: %{description: "Remédios", category_id: c_farmacia.id}, account_id: acc_bb.id, value: -230},

        %{date: Timex.shift(month_first, days: 5, months: 1), originator: "transfer", transfer: %{other_account_id: acc_nu.id}, account_id: acc_bb.id, value: -1086}
      ]
      |> Enum.map(fn attrs -> 
        {:ok, _ } = Transactions.Transaction.Form.apply_insert(attrs)
      end)
    end
  end

  def down do
  end
end

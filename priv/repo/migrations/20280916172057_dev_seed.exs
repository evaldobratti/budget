defmodule Budget.Repo.Migrations.DevSeed do
  alias Budget.Users
  alias Budget.Transactions

  use Ecto.Migration

  def up do
    if Application.get_env(:budget, :environment, %{}) |> Map.get(:name) == :dev do
      {:ok, user} = Users.create_user(%{email: "mocked@provider.com", google_id: "-1", name: "Dev User"})

      Budget.Repo.put_user_id(user.id)

      {:ok, acc_bb} = Transactions.create_account(%{
        initial_balance: -100,
        name: "Banco do Brasil"
      })

      {:ok, acc_nu} = Transactions.create_account(%{
        initial_balance: -100,
        name: "CC NuBank"
      })

      c_alimentacao = Transactions.get_category_by_name!("Alimentação")
      c_mercado = Transactions.get_category_by_name!("Mercado")
      c_lazer = Transactions.get_category_by_name!("Lazer")
      c_receita = Transactions.get_category_by_name!("Receitas")
      c_saude = Transactions.get_category_by_name!("Saúde")
      c_farmacia = Transactions.get_category_by_name!("Farmácia")
      c_consultas = Transactions.get_category_by_name!("Consultas")
      c_moradia = Transactions.get_category_by_name!("Moradia")
      c_transporte = Transactions.get_category_by_name!("Transporte")
      c_impostos = Transactions.get_category_by_name!("Impostos")
      c_vestuario = Transactions.get_category_by_name!("Vestuário")
      c_presentes = Transactions.get_category_by_name!("Presentes")
      c_viagem = Transactions.get_category_by_name!("Viagem")
      c_mensalidades = Transactions.get_category_by_name!("Mensalidades")
      c_educacao = Transactions.get_category_by_name!("Educação")

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

      Budget.Repo.put_user_id(nil)
    end
  end

  def down do
  end
end

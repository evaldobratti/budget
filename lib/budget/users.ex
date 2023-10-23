defmodule Budget.Users do

  import Ecto.Query

  alias Budget.Transactions
  alias Budget.Users.User
  alias Budget.Repo
  
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, user} ->
        create_welcoming_data(user)

        {:ok, user}

      error ->
        error
    end
  end

  def fetch_user_by_google_id(google_id) do
    user = 
      from(
        u in User,
        where: u.google_id == ^google_id
      )
      |> Repo.one(skip_user_id: true)

    case user do
      nil -> :not_found
      value -> {:ok, value}
    end
  end

  def get_user_by_email!(email) do
    from(
      u in User,
      where: u.email == ^email
    )
    |> Repo.one!(skip_user_id: true)
  end

  def create_welcoming_data(user) do
    Budget.Repo.put_user_id(user.id)

    {:ok, _} = Transactions.create_category(%{name: "Alimentação"})
    {:ok, _} = Transactions.create_category(%{name: "Mercado"})
    {:ok, _} = Transactions.create_category(%{name: "Lazer"})
    {:ok, _} = Transactions.create_category(%{name: "Receitas"})
    {:ok, c_saude} = Transactions.create_category(%{name: "Saúde"})
    {:ok, _} = Transactions.create_category(%{name: "Farmácia"}, c_saude)
    {:ok, _} = Transactions.create_category(%{name: "Consultas"}, c_saude)
    {:ok, _} = Transactions.create_category(%{name: "Moradia"})
    {:ok, _} = Transactions.create_category(%{name: "Transporte"})
    {:ok, _} = Transactions.create_category(%{name: "Impostos"})
    {:ok, _} = Transactions.create_category(%{name: "Vestuário"})
    {:ok, _} = Transactions.create_category(%{name: "Presentes"})
    {:ok, _} = Transactions.create_category(%{name: "Viagem"})
    {:ok, _} = Transactions.create_category(%{name: "Mensalidades"})
    {:ok, _} = Transactions.create_category(%{name: "Educação"})
  end
end

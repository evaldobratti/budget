defmodule Budget.Users do

  import Ecto.Query

  alias Budget.Users.User
  alias Budget.Repo
  
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
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
end

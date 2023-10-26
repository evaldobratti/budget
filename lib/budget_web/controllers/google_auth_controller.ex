defmodule BudgetWeb.GoogleAuthController do
  use BudgetWeb, :controller

  alias Budget.Users

  def login(conn, _params) do
    cond do
      get_session(conn, :user) ->
        conn
        |> redirect(to: ~p"/")

      :budget
      |> Application.get_env(:environment, %{})
      |> Map.get(:name) == :dev ->

        dev_user = Users.get_user_by_email!("mocked@provider.com")

        conn
        |> put_session(:user, dev_user)
        |> put_session(:active_profile, Enum.at(dev_user.profiles, 0))

        |> redirect(to: ~p"/")

      true ->
        conn
        |> render(:login, [
          google_oauth_url: ElixirAuthGoogle.generate_oauth_url(BudgetWeb.Endpoint.url())
        ])
    end
  end

  def signin(conn, %{"code" => code}) do
    {:ok, token} = ElixirAuthGoogle.get_token(code, BudgetWeb.Endpoint.url())
    {:ok, google_profile} = ElixirAuthGoogle.get_user_profile(token.access_token)

    user =
      case Users.fetch_user_by_google_id(google_profile.sub) do
        :not_found ->
          {:ok, user} =
          google_profile
            |> Map.put(:google_id, google_profile.sub)
            |> Map.put(:profiles, [%{name: "Padrão"}])
            |> Users.create_user()

          user

        {:ok, user} ->
          user
      end

    conn
    |> put_session(:user, Map.merge(google_profile, user))
    |> put_session(:active_profile, Enum.at(user.profiles, 0))
    |> redirect(to: ~p"/")
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> redirect(to: ~p"/login")
  end

  def check_login(conn, _opts) do
    if get_session(conn, :user) do
      conn
    else
      conn
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end
end

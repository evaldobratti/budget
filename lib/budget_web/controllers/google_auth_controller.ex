defmodule BudgetWeb.GoogleAuthController do
  use BudgetWeb, :controller

  def login(conn, _params) do
    if get_session(conn, :profile) do
      conn
      |> redirect(to: ~p"/")
    else 
      conn
      |> render(:login, [
        google_oauth_url: ElixirAuthGoogle.generate_oauth_url(conn)
      ])
    end

  end

  def signin(conn, %{"code" => code}) do
    {:ok, token} = ElixirAuthGoogle.get_token(code, BudgetWeb.Endpoint.url())
    {:ok, profile} = ElixirAuthGoogle.get_user_profile(token.access_token)

    conn
    |> put_session(:profile, profile)
    |> redirect(to: ~p"/")
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> redirect(to: ~p"/login")
  end

  def check_login(conn, _opts) do
    if get_session(conn, :profile) do
      conn
    else
      conn
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end
end

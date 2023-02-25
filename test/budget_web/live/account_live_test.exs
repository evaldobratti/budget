defmodule BudgetWeb.AccountLiveTest do
  use BudgetWeb.ConnCase

  import Phoenix.LiveViewTest
  import Budget.TransactionsFixtures

  @create_attrs %{initial_balance: "120.5", name: "some name"}
  @update_attrs %{initial_balance: "456.7", name: "some updated name"}
  @invalid_attrs %{initial_balance: nil, name: nil}

  defp create_account(_) do
    account = account_fixture()
    %{account: account}
  end

  describe "Index" do
    setup [:create_account]

    @tag :skip
    test "lists all accounts", %{conn: conn, account: account} do
      {:ok, _index_live, html} = live(conn, Routes.account_index_path(conn, :index))

      assert html =~ "Listing Accounts"
      assert html =~ account.name
    end

    @tag :skip
    test "saves new account", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, Routes.account_index_path(conn, :index))

      assert index_live |> element("a", "New Account") |> render_click() =~
               "New Account"

      assert_patch(index_live, Routes.account_index_path(conn, :new))

      assert index_live
             |> form("#account-form", account: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#account-form", account: @create_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.account_index_path(conn, :index))

      assert html =~ "Account created successfully"
      assert html =~ "some name"
    end

    @tag :skip
    test "updates account in listing", %{conn: conn, account: account} do
      {:ok, index_live, _html} = live(conn, Routes.account_index_path(conn, :index))

      assert index_live |> element("#account-#{account.id} a", "Edit") |> render_click() =~
               "Edit Account"

      assert_patch(index_live, Routes.account_index_path(conn, :edit, account))

      assert index_live
             |> form("#account-form", account: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#account-form", account: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.account_index_path(conn, :index))

      assert html =~ "Account updated successfully"
      assert html =~ "some updated name"
    end
  end
end

defmodule BudgetWeb.ImportLive.ResultTest do
  use BudgetWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Budget.TransactionsFixtures

  alias Budget.Importations
  alias Budget.Repo
  alias Budget.Transactions

  setup do
    %{
      category: category_fixture(),
      account: account_fixture()
    }
  end

  test "renders imported file", %{conn: conn} do
    {:ok, key} =
      Importations.import("test/budget/importations/files/credit_card/nu_bank/simple.txt")

    {:ok, live, _html} = live(conn, Routes.import_result_path(conn, :index, key))

    html = render(live)

    form0 =
      live
      |> element("#transaction-0")
      |> render()

    assert form0 =~ "2022-08-30"
    assert form0 =~ "Kabum - 5/6"
    assert form0 =~ "2.29"

    form1 =
      live
      |> element("#transaction-1")
      |> render()

    assert form1 =~ "2022-08-30"
    assert form1 =~ "Panvel Filial"
    assert form1 =~ "4.01"
  end

  test "show errors when importing", %{conn: conn} do
    {:ok, key} =
      Importations.import("test/budget/importations/files/credit_card/nu_bank/simple.txt")

    {:ok, live, _html} = live(conn, Routes.import_result_path(conn, :index, key))

    live
    |> element("button", "Import")
    |> render_click()

    html = render(live)

    assert html =~ "can&#39;t be blank"
  end

  test "imports file updating fields", %{conn: conn, category: category, account: account} do
    {:ok, key} =
      Importations.import("test/budget/importations/files/credit_card/nu_bank/simple.txt")

    {:ok, live, _html} = live(conn, Routes.import_result_path(conn, :index, key))

    assert [] ==
             Transactions.transactions_in_period(
               [],
               Timex.today() |> Timex.beginning_of_month(),
               Timex.today() |> Timex.end_of_month()
             )

    live
    |> form("#transaction-0",
      form: %{
        date: Date.utc_today() |> Date.to_iso8601(),
        regular: %{
          description: "updated",
          category_id: category.id
        },
        value: 11
      }
    )
    |> render_change()

    live
    |> form("#transaction-1",
      form: %{
        date: Date.utc_today() |> Date.to_iso8601(),
        regular: %{
          category_id: category.id
        }
      }
    )
    |> render_change()

    {:ok, live, _html} =
      live
      |> element("button", "Import")
      |> render_click()
      |> follow_redirect(conn)

    assert [
             %{
               account_id: account.id,
               date: Timex.today(),
               is_carried_out: false,
               originator: %{category_id: category.id, description: "updated"},
               value: 11.0
             },
             %{
               account_id: account.id,
               date: Timex.today(),
               is_carried_out: false,
               originator: %{category_id: category.id, description: "Panvel Filial"},
               value: -4.01
             }
           ] ==
             Transactions.transactions_in_period(
               [],
               Timex.today() |> Timex.beginning_of_month(),
               Timex.today() |> Timex.end_of_month()
             )
             |> Enum.map(&simplify/1)
  end
end

defmodule BudgetWeb.ImportLive.ResultTest do
  use BudgetWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Budget.ImportationsFixtures
  import Budget.TransactionsFixtures
  import Budget.ImportationsFixtures

  alias Budget.Importations
  alias Budget.Transactions

  setup do
    %{
      category: category_fixture(),
      account: account_fixture(),
      import_file: import_file_fixture(:simple)
    }
  end

  test "renders imported file", %{conn: conn, import_file: import_file} do
    {:ok, live, _html} = live(conn, ~p"/imports/#{import_file.id}")

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

  test "show errors when importing", %{conn: conn, import_file: import_file} do
    {:ok, live, _html} = live(conn, ~p"/imports/#{import_file.id}")

    live
    |> element("button", "Import")
    |> render_click()

    html = render(live)

    assert html =~ "can&#39;t be blank"
  end

  test "imports file updating fields", %{conn: conn, category: category, account: account, import_file: import_file} do
    {:ok, live, _html} = live(conn, ~p"/imports/#{import_file.id}")

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

    assert %{
             path: "test/budget/importations/files/credit_card/nu_bank/simple.txt",
             hashes: ["0-2022-08-30--2.29-Kabum - 5/6", "1-2022-08-30--4.01-Panvel Filial"]
           } = Importations.list_import_files() |> Enum.at(0)
  end

  test "renders warning if reimporting file", %{conn: conn, category: category, account: account, import_file: import_file} do
    {:ok, live, _html} = live(conn, ~p"/imports/#{import_file.id}")

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

    live
    |> element("button", "Import")
    |> render_click()
    |> follow_redirect(conn)

    assert 2 ==
             Transactions.transactions_in_period(
               [],
               Timex.today() |> Timex.beginning_of_month(),
               Timex.today() |> Timex.end_of_month()
             )
             |> length

    same_file = import_file_fixture(:simple)

    {:ok, live, _html} = live(conn, ~p"/imports/#{same_file.id}")

    assert live
           |> element(".hero-exclamation-circle")
           |> has_element?()
  end

  test "removes transaction from import", %{conn: conn, category: category, account: account, import_file: import_file} do
    {:ok, live, _html} = live(conn, ~p"/imports/#{import_file.id}")

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
    |> element("#delete-1")
    |> render_click()

    live
    |> element("button", "Import")
    |> render_click()
    |> follow_redirect(conn)

    assert 1 ==
             Transactions.transactions_in_period(
               [],
               Timex.today() |> Timex.beginning_of_month(),
               Timex.today() |> Timex.end_of_month()
             )
             |> length

    same_file = import_file_fixture(:simple)

    {:ok, live, _html} = live(conn, ~p"/imports/#{same_file.id}")

    render(live)

    open_browser(live)

    assert live
           |> element("#warning-0")
           |> has_element?()

    refute live
           |> element("#warning-1")
           |> has_element?()
  end
end

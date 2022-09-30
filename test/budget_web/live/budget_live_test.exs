defmodule BudgetWeb.BudgetLiveTest do
  use BudgetWeb.ConnCase

  import Phoenix.LiveViewTest
  import Budget.EntriesFixtures
  alias Budget.Repo

  defp create_account(_) do
    account = account_fixture()
    %{account: account}
  end

  def debug(html) do
    html
    |> Floki.parse_fragment!()
    |> Floki.raw_html(pretty: true)
    |> IO.puts()
  end

  describe "accounts" do
    setup :create_account

    test "lists accounts", %{conn: conn, account: account} do
      {:ok, _index_live, html} = live(conn, Routes.budget_index_path(conn, :index))

      assert html =~ account.name
    end

    test "create new account", %{conn: conn} do
      {:ok, live, _html} = live(conn, Routes.budget_index_path(conn, :index))

      live
      |> element("button", "New Account")
      |> render_click()

      live
      |> form("#account-form", account: %{name: "another account", initial_balance: "133"})
      |> render_submit()

      html = render(live)

      refute live |> element("#account-form") |> has_element?

      assert html =~ "Account Name"
      assert html =~ "another account"
    end
  end

  describe "entries" do

    setup :create_account

    test "create new entry", %{conn: conn, account: account} do
      {:ok, live, _html} = live(conn, Routes.budget_index_path(conn, :index))

      live
      |> element("button", "New Entry")
      |> render_click()

      live
      |> form("#coumpound-form", compound_entry: %{
        entry: %{
          date: Timex.today() |> Timex.format!("{YYYY}-{0M}-{0D}"),
          description: "a description",
          account_id: account.id,
          value: "200"
        }
      })
      |> render_submit()

      refute live |> element("#coumpound-form") |> has_element?

      entry = Repo.one(Budget.Entries.Entry)

      assert live |> element("#previous-balance") |> render =~ "120,50"
      assert live |> element("#entry-#{entry.id}") |> render =~ "200,00"
      assert live |> element("#next-balance") |> render =~ "320,50"
    end

    test "navigating through months via form", %{conn: conn, account: account} do
      today = entry_fixture(value: 200, account_id: account.id)

      last_month = entry_fixture(
        date: Timex.today |> Timex.shift(months: -1) |> Date.to_iso8601(),
        value: 300, 
        account_id: account.id
      )

      next_month = entry_fixture(
        date: Timex.today |> Timex.shift(months: 1) |> Date.to_iso8601(),
        value: 400, 
        account_id: account.id
      )

      {:ok, live, _html} = live(conn, Routes.budget_index_path(conn, :index))

      assert live |> element("#previous-balance") |> render =~ "420,50"
      assert live |> element("#entry-#{today.id}") |> render =~ "200,00"
      assert live |> element("#next-balance") |> render =~ "620,50"

      last_month_start = Timex.today() |> Timex.shift(months: -1) |> Timex.beginning_of_month()
      last_month_end = Timex.today() |> Timex.shift(months: -1) |> Timex.end_of_month()
      
      live
      |> form("#dates-switch")
      |> render_change(%{
        "date-start" => last_month_start |> Date.to_iso8601(),
        "date-end" => last_month_end |> Date.to_iso8601(),
      })

      assert live |> element("#previous-balance") |> render =~ "120,50"
      assert live |> element("#entry-#{last_month.id}") |> render =~ "300,00"
      assert live |> element("#next-balance") |> render =~ "420,50"

      next_month_start = Timex.today() |> Timex.shift(months: 1) |> Timex.beginning_of_month()
      next_month_end = Timex.today() |> Timex.shift(months: 1) |> Timex.end_of_month()
      
      live
      |> form("#dates-switch")
      |> render_change(%{
        "date-start" => next_month_start |> Date.to_iso8601(),
        "date-end" => next_month_end |> Date.to_iso8601(),
      })

      assert live |> element("#previous-balance") |> render =~ "620,50"
      assert live |> element("#entry-#{next_month.id}") |> render =~ "400,00"
      assert live |> element("#next-balance") |> render =~ "1.020,50"
    end

    test "navigating through months via buttons", %{conn: conn, account: account} do
      today = entry_fixture(value: 200, account_id: account.id)

      last_month = entry_fixture(
        date: Timex.today |> Timex.shift(months: -1) |> Date.to_iso8601(),
        value: 300, 
        account_id: account.id
      )

      next_month = entry_fixture(
        date: Timex.today |> Timex.shift(months: 1) |> Date.to_iso8601(),
        value: 400, 
        account_id: account.id
      )

      {:ok, live, _html} = live(conn, Routes.budget_index_path(conn, :index))

      assert live |> element("#previous-balance") |> render =~ "420,50"
      assert live |> element("#entry-#{today.id}") |> render =~ "200,00"
      assert live |> element("#next-balance") |> render =~ "620,50"

      live
      |> element("button", "<<")
      |> render_click()

      assert live |> element("#previous-balance") |> render =~ "120,50"
      assert live |> element("#entry-#{last_month.id}") |> render =~ "300,00"
      assert live |> element("#next-balance") |> render =~ "420,50"

      live
      |> element("button", ">>")
      |> render_click()

      live
      |> element("button", ">>")
      |> render_click()

      assert live |> element("#previous-balance") |> render =~ "620,50"
      assert live |> element("#entry-#{next_month.id}") |> render =~ "400,00"
      assert live |> element("#next-balance") |> render =~ "1.020,50"
    end
  end

  describe "recurrencies" do

    setup :create_account

    test "create entry with recurrency", %{conn: conn, account: account} do
      {:ok, live, _html} = live(conn, Routes.budget_index_path(conn, :index))

      live
      |> element("button", "New Entry")
      |> render_click()

      live
      |> form("#coumpound-form", compound_entry: %{
        entry: %{
          date: Timex.today() |> Timex.format!("{YYYY}-{0M}-{0D}"),
          description: "a description",
          account_id: account.id,
          value: "200"
        },
        is_recurrency: true,
      })
      |> render_change()

      live
      |> form("#coumpound-form", compound_entry: %{
        entry: %{
          date: Timex.today() |> Timex.format!("{YYYY}-{0M}-{0D}"),
          description: "a description",
          account_id: account.id,
          value: "200"
        },
        is_recurrency: true,
        recurrency: %{
          is_forever: true,
          frequency: :monthly,
        }
      })
      |> render_submit()

      refute live |> element("#coumpound-form") |> has_element?
      
      entry = Repo.one(Budget.Entries.Entry)

      assert live |> element("#previous-balance") |> render =~ "120,50"
      assert live |> element("#entry-#{entry.id}") |> render =~ "200,00"
      assert live |> element("#next-balance") |> render =~ "320,50"

      live
      |> element("button", ">>")
      |> render_click()

      recurrency = Repo.one(Budget.Entries.Recurrency)

      next_month_entry = Timex.today |> Timex.shift(months: 1) |> Date.to_iso8601()

      assert live |> element("#previous-balance") |> render =~ "320,50"
      assert live |> element("#entry-recurrency-#{recurrency.id}-#{next_month_entry}") |> render =~ "200,00"
      assert live |> element("#next-balance") |> render =~ "520,50"
    end
  end
end

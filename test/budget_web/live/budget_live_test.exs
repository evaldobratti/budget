defmodule BudgetWeb.BudgetLiveTest do
  use BudgetWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Budget.EntriesFixtures

  alias Budget.Repo
  alias Budget.Entries

  defp create_account(_) do
    account = account_fixture()
    %{account: account}
  end

  defp create_category(_) do
    %{category: category_fixture()}
  end

  def debug(html) do
    html
    |> Floki.parse_fragment!()
    |> Floki.raw_html(pretty: true)
    |> IO.puts()
  end

  setup [:create_account, :create_category]

  describe "accounts" do
    test "lists accounts", %{conn: conn, account: account} do
      {:ok, _index_live, html} = live(conn, Routes.budget_index_path(conn, :index))

      assert html =~ account.name
    end

    test "create new account", %{conn: conn} do
      {:ok, live, _html} = live(conn, Routes.budget_index_path(conn, :index))

      live
      |> element("a[href='#{Routes.budget_index_path(conn, :new_account)}']")
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
    test "create new entry", %{conn: conn, account: account, category: category} do
      {:ok, live, _html} = live(conn, Routes.budget_index_path(conn, :index))

      live
      |> element("a", "New Entry")
      |> render_click()

      live
      |> form("#entry-form",
        entry: %{
          date: Timex.today() |> Timex.format!("{YYYY}-{0M}-{0D}"),
          originator_regular: %{
            description: "a description",
            category_id: category.id,
          },
          account_id: account.id,
          value: "200"
        }
      )
      |> render_submit()

      refute live |> element("#entry-form") |> has_element?

      entry = Repo.one(Budget.Entries.Entry)

      assert live |> element("#previous-balance") |> render =~ "120,50"
      assert live |> element("#entry-#{entry.id}") |> render =~ "200,00"
      assert live |> element("#next-balance") |> render =~ "320,50"
    end

    test "editing entry", %{conn: conn, account: account} do
      entry = entry_fixture(%{account_id: account.id})

      {:ok, live, _html} = live(conn, Routes.budget_index_path(conn, :index))

      live
      |> element("a", "Entry description")
      |> render_click()

      live
      |> form("#entry-form",
        entry: %{
          originator_regular: %{description: "a new description"},
          value: "400"
        }
      )
      |> render_submit()

      updated = Entries.get_entry!(entry.id)

      assert updated.value == Decimal.new(400)
      assert updated.originator_regular.description == "a new description"
    end

    test "navigating through months via form", %{conn: conn, account: account} do
      today = entry_fixture(%{value: 200, account_id: account.id})

      last_month =
        entry_fixture(%{
          date: Timex.today() |> Timex.shift(months: -1) |> Date.to_iso8601(),
          value: 300,
          account_id: account.id
        })

      next_month =
        entry_fixture(%{
          date: Timex.today() |> Timex.shift(months: 1) |> Date.to_iso8601(),
          value: 400,
          account_id: account.id
        })

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
        "date-end" => last_month_end |> Date.to_iso8601()
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
        "date-end" => next_month_end |> Date.to_iso8601()
      })

      assert live |> element("#previous-balance") |> render =~ "620,50"
      assert live |> element("#entry-#{next_month.id}") |> render =~ "400,00"
      assert live |> element("#next-balance") |> render =~ "1.020,50"
    end

    test "navigating through months via buttons", %{conn: conn, account: account} do
      today = entry_fixture(%{value: 200, account_id: account.id})

      last_month =
        entry_fixture(%{
          date: Timex.today() |> Timex.shift(months: -1) |> Date.to_iso8601(),
          value: 300,
          account_id: account.id
        })

      next_month =
        entry_fixture(%{
          date: Timex.today() |> Timex.shift(months: 1) |> Date.to_iso8601(),
          value: 400,
          account_id: account.id
        })

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
    test "create entry with recurrency", %{conn: conn, account: account, category: category} do
      {:ok, live, _html} = live(conn, Routes.budget_index_path(conn, :index))

      live
      |> element("a", "New Entry")
      |> render_click()

      live
      |> form("#entry-form",
        entry: %{
          date: Timex.today() |> Timex.format!("{YYYY}-{0M}-{0D}"),
          originator_regular: %{
            description: "a description",
            category_id: category.id
          },
          account_id: account.id,
          value: "200",
          is_recurrency: true
        }
      )
      |> render_change()

      live
      |> form("#entry-form",
        entry: %{
          date: Timex.today() |> Timex.format!("{YYYY}-{0M}-{0D}"),
          originator_regular: %{
            description: "a description",
            category_id: category.id
          },
          account_id: account.id,
          value: "200",
          is_recurrency: true,
          recurrency_entry: %{
            recurrency: %{
              is_forever: true,
              frequency: :monthly
            }
          }
        }
      )
      |> render_submit()

      refute live |> element("#entry-form") |> has_element?

      entry = Repo.one(Budget.Entries.Entry)

      assert live |> element("#previous-balance") |> render =~ "120,50"
      assert live |> element("#entry-#{entry.id}") |> render =~ "200,00"
      assert live |> element("#next-balance") |> render =~ "320,50"

      live
      |> element("button", ">>")
      |> render_click()

      recurrency = Repo.one(Budget.Entries.Recurrency)

      next_month_entry = Timex.today() |> Timex.shift(months: 1) |> Date.to_iso8601()

      assert live |> element("#previous-balance") |> render =~ "320,50"

      assert live |> element("#entry-recurrency-#{recurrency.id}-#{next_month_entry}") |> render =~
               "200,00"

      assert live |> element("#next-balance") |> render =~ "520,50"
    end

    test "edit existing entry from recurrency", %{conn: conn} do
      recurrency = recurrency_fixture()

      {:ok, live, _html} = live(conn, Routes.budget_index_path(conn, :index))

      live
      |> element("a", "Entry description")
      |> render_click()

      live
      |> form("#entry-form",
        entry: %{
          originator_regular: %{
            description: "a new description"
          },
          value: "420"
        }
      )
      |> render_submit()

      updated =
        recurrency.id
        |> Entries.get_recurrency!()
        |> then(& &1.recurrency_entries)
        |> Enum.at(0)
        |> then(& &1.entry.id)
        |> Entries.get_entry!()

      assert updated.value == Decimal.new(420)
      assert updated.originator_regular.description == "a new description"
    end

    test "edit transient entry from recurrency", %{conn: conn} do
      recurrency = recurrency_fixture()
      another_category = category_fixture()

      {:ok, live, _html} = live(conn, Routes.budget_index_path(conn, :index))

      live
      |> element("button", ">>")
      |> render_click()

      live
      |> element("a", "Entry description")
      |> render_click()

      live
      |> form("#entry-form",
        entry: %{
          date: ~D[2020-06-13],
          originator_regular: %{
            description: "a new description",
            category_id: another_category.id
          },
          value: "420"
        }
      )
      |> render_submit()

      recurrency = Entries.get_recurrency!(recurrency.id)

      assert length(recurrency.recurrency_entries) == 2

      recurrency_entry =
        Enum.find(recurrency.recurrency_entries, &(&1.entry.value == Decimal.new(420)))

      entry = recurrency_entry.entry

      assert entry.originator_regular.description == "a new description"
      assert recurrency_entry.original_date == Timex.today() |> Timex.shift(months: 1)
      assert entry.date == ~D[2020-06-13]
    end

    test "edit a persistent entry from recurrency", %{conn: conn} do
      recurrency = recurrency_fixture()

      {:ok, %{id: id}} =
        recurrency.id
        |> Entries.get_recurrency!()
        |> Entries.recurrency_entries(Timex.today() |> Timex.shift(months: 3))
        |> Enum.at(0)
        |> Entries.create_entry(%{})

      {:ok, live, _html} = live(conn, Routes.budget_index_path(conn, :index))

      live
      |> element("button", ">>")
      |> render_click()

      live
      |> element("a", "Entry description")
      |> render_click()

      path = assert_patch(live)
      assert path == BudgetWeb.Router.Helpers.budget_index_path(conn, :edit_entry, id)

      live
      |> form("#entry-form",
        entry: %{
          date: ~D[2020-06-13],
          originator_regular: %{
            description: "a new description",
          },
          value: "420"
        }
      )
      |> render_submit()

      recurrency = Entries.get_recurrency!(recurrency.id)

      assert length(recurrency.recurrency_entries) == 2

      entry = Entries.get_entry!(id)

      assert entry.originator_regular.description == "a new description"
      assert entry.date == ~D[2020-06-13]
      assert entry.value == Decimal.new(420)
    end
  end

  test "delete single entry", %{conn: conn, account: account} do
    entry = entry_fixture(%{account_id: account.id})

    {:ok, live, _html} = live(conn, Routes.budget_index_path(conn, :index))

    live
    |> element("[data-testid=delete-#{entry.id}]")
    |> render_click()

    assert live
           |> element("button", "Yes")
           |> render_click() =~ "Entry successfully deleted!"
  end

  test "delete recurrent entry and the next transient one", %{conn: conn} do
    recurrency = recurrency_fixture()

    entry = recurrency.recurrency_entries |> Enum.at(0) |> then(& &1.entry)

    {:ok, live, html} = live(conn, Routes.budget_index_path(conn, :index))

    assert html =~ "Entry description"

    html =
      live
      |> element("[data-testid=delete-#{entry.id}]")
      |> render_click()

    assert html =~ "Delete just this entry"
    assert html =~ "Delete this entry and future entries"

    html =
      live
      |> element("button", "Delete just this entry")
      |> render_click()

    assert html =~ "Entry successfully deleted!"
    refute html =~ "Entry description"
  end

  test "delete recurrent transient entry", %{conn: conn} do
    recurrency_fixture()

    {:ok, live, _html} = live(conn, Routes.budget_index_path(conn, :index))

    html =
      live
      |> element("button", ">>")
      |> render_click()

    assert html =~ "Entry description"

    html =
      live
      |> element("[data-testid^=delete-]")
      |> render_click()

    assert html =~ "Delete just this entry"
    assert html =~ "Delete this entry and future entries"

    html =
      live
      |> element("button", "Delete this entry and future entries")
      |> render_click()

    assert html =~ "Entry successfully deleted!"
    refute html =~ "Entry description"

    html =
      live
      |> element("button", ">>")
      |> render_click()

    refute html =~ "Entry description"
  end

  test "delete recurrent transient with future persisted", %{conn: conn} do
    recurrency_fixture()

    {:ok, live, _html} = live(conn, Routes.budget_index_path(conn, :index))

    live
    |> element("button", ">>")
    |> render_click()

    live
    |> element("button", ">>")
    |> render_click()

    live
    |> element("button", ">>")
    |> render_click()

    live
    |> element("a", "Entry description")
    |> render_click()

    live
    |> form("#entry-form")
    |> render_submit()

    html = render(live)

    assert html =~ "Entry updated successfully!"

    live
    |> element("button", "<<")
    |> render_click()

    live
    |> element("button", "<<")
    |> render_click()

    html =
      live
      |> element("[data-testid^=delete-]")
      |> render_click()

    assert html =~ "Delete just this entry"
    assert html =~ "Delete this entry with future ones but keep changed ones"
    assert html =~ "Delete this entry and all future ones"

    html =
      live
      |> element("button", "Delete this entry with future ones but keep changed ones")
      |> render_click()

    assert html =~ "Entry successfully deleted!"

    refute live
           |> element("button", ">>")
           |> render_click() =~ "Entry description"

    assert live
           |> element("button", ">>")
           |> render_click() =~ "Entry description"
  end

  test "create new category", %{conn: conn} do
    {:ok, live, _html} = live(conn, Routes.budget_index_path(conn, :index))

    live
    |> element("a[href='#{Routes.budget_index_path(conn, :new_category)}']")
    |> render_click()

    live
    |> form("#category-form", category: %{name: "test category"})
    |> render_submit()

    html = render(live)

    assert html =~ "Category created successfully"
    assert html =~ "test category"
  end

  test "create new child category", %{conn: conn, category: category} do
    {:ok, live, _html} = live(conn, Routes.budget_index_path(conn, :index))

    live
    |> element("a[href='#{Routes.budget_index_path(conn, :new_category_child, category)}']")
    |> render_click()

    assert render(live) =~ "Creating a child category of &#39;root category&#39;"

    live
    |> form("#category-form", category: %{name: "test category"})
    |> render_submit()

    html = render(live)

    assert html =~ "Category created successfully"
    assert html =~ "test category"
  end

  test "edit category", %{conn: conn, category: category} do
    {:ok, live, _html} = live(conn, Routes.budget_index_path(conn, :index))

    live
    |> element("a[href='#{Routes.budget_index_path(conn, :edit_category, category)}']")
    |> render_click()

    live
    |> form("#category-form", category: %{name: "another category name"})
    |> render_submit()

    html = render(live)

    assert html =~ "Category updated successfully"
    assert html =~ "another category name"
  end
end

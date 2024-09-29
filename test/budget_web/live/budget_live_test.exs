defmodule BudgetWeb.BudgetLiveTest do
  use BudgetWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Budget.TransactionsFixtures

  alias Budget.Repo
  alias Budget.Transactions

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
  end

  setup [:create_account, :create_category]

  describe "accounts" do
    test "lists accounts", %{conn: conn, account: account} do
      {:ok, _index_live, html} = live(conn, ~p"/")

      assert html =~ account.name
    end

    test "create new account", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      live
      |> element("a[href='#{~p"/accounts/new"}']")
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

  describe "transactions" do
    test "create new transaction", %{conn: conn, account: account, category: category} do
      {:ok, live, _html} = live(conn, ~p"/")

      live
      |> element("a[href='#{~p"/transactions/new"}']")
      |> render_click()

      live
      |> form("#transaction-form",
        form: %{
          date: Timex.today() |> Timex.format!("{YYYY}-{0M}-{0D}"),
          regular: %{
            description: "a description",
            category_id: category.id
          },
          account_id: account.id,
          value: "200"
        }
      )
      |> render_submit()

      refute live |> element("#transaction-form") |> has_element?

      transaction = Repo.one(Budget.Transactions.Transaction)

      assert live |> element("#previous-balance") |> render =~ "120,50"
      assert live |> element("#transaction-#{transaction.id}") |> render =~ "200,00"
      assert live |> element("#next-balance") |> render =~ "320,50"
    end

    test "keeps adding transactions and keeps date and account from previous transaction", %{
      conn: conn,
      account: account,
      category: category
    } do
      {:ok, live, _html} = live(conn, ~p"/")

      another_account = account_fixture()

      live
      |> element("a[href='#{~p"/transactions/new"}']")
      |> render_click()

      live
      |> form("#transaction-form",
        form: %{
          date: "2020-02-20",
          regular: %{
            description: "a description",
            category_id: category.id
          },
          account_id: another_account.id,
          keep_adding: true,
          value: "200"
        }
      )
      |> render_submit()

      refute live |> element("#transaction-form") |> has_element?

      assert "/transactions/new" == assert_patch(live, 100)

      assert "/?account_id=#{another_account.id}&date=2020-02-20&from=transaction&transaction-add-new=true" ==
               assert_patch(live, 100)

      assert "/transactions/new?from=transaction" == assert_patch(live, 300)

      assert ["2020-02-20"] ==
               live
               |> element("#transaction-form")
               |> render()
               |> Floki.parse_fragment!()
               |> Floki.find("[name='form[date]']")
               |> Floki.attribute("value")

      assert [to_string(another_account.id)] ==
               live
               |> element("#transaction-form")
               |> render()
               |> Floki.parse_fragment!()
               |> Floki.find("[selected='selected']")
               |> Floki.attribute("value")
    end

    test "editing transaction", %{conn: conn, account: account} do
      transaction = transaction_fixture(%{account_id: account.id})

      {:ok, live, _html} = live(conn, ~p"/")

      live
      |> element("a", "Transaction description")
      |> render_click()

      live
      |> form("#transaction-form",
        form: %{
          regular: %{description: "a new description"},
          value: "400"
        }
      )
      |> render_submit()

      updated = Transactions.get_transaction!(transaction.id)

      assert updated.value == Decimal.new(400)
      assert updated.originator_regular.description == "a new description"
    end

    test "navigating through months via form", %{conn: conn, account: account} do
      today = transaction_fixture(%{value: 200, account_id: account.id})

      last_month =
        transaction_fixture(%{
          date: Timex.today() |> Timex.shift(months: -1) |> Date.to_iso8601(),
          value: 300,
          account_id: account.id
        })

      next_month =
        transaction_fixture(%{
          date: Timex.today() |> Timex.shift(months: 1) |> Date.to_iso8601(),
          value: 400,
          account_id: account.id
        })

      {:ok, live, _html} = live(conn, ~p"/")

      assert live |> element("#previous-balance") |> render =~ "420,50"
      assert live |> element("#transaction-#{today.id}") |> render =~ "200,00"
      assert live |> element("#next-balance") |> render =~ "620,50"

      last_month_start = Timex.today() |> Timex.shift(months: -1) |> Timex.beginning_of_month()
      last_month_end = Timex.today() |> Timex.shift(months: -1) |> Timex.end_of_month()

      live
      |> form("#dates-switch")
      |> render_change(%{
        "date_start" => last_month_start |> Date.to_iso8601(),
        "date_end" => last_month_end |> Date.to_iso8601()
      })

      assert live |> element("#previous-balance") |> render =~ "120,50"
      assert live |> element("#transaction-#{last_month.id}") |> render =~ "300,00"
      assert live |> element("#next-balance") |> render =~ "420,50"

      next_month_start = Timex.today() |> Timex.shift(months: 1) |> Timex.beginning_of_month()
      next_month_end = Timex.today() |> Timex.shift(months: 1) |> Timex.end_of_month()

      live
      |> form("#dates-switch")
      |> render_change(%{
        "date_start" => next_month_start |> Date.to_iso8601(),
        "date_end" => next_month_end |> Date.to_iso8601()
      })

      assert live |> element("#previous-balance") |> render =~ "620,50"
      assert live |> element("#transaction-#{next_month.id}") |> render =~ "400,00"
      assert live |> element("#next-balance") |> render =~ "1.020,50"
    end

    test "navigating through months via buttons", %{conn: conn, account: account} do
      today = transaction_fixture(%{value: 200, account_id: account.id})

      last_month =
        transaction_fixture(%{
          date: Timex.today() |> Timex.shift(months: -1) |> Date.to_iso8601(),
          value: 300,
          account_id: account.id
        })

      next_month =
        transaction_fixture(%{
          date: Timex.today() |> Timex.shift(months: 1) |> Date.to_iso8601(),
          value: 400,
          account_id: account.id
        })

      {:ok, live, _html} = live(conn, ~p"/")

      assert live |> element("#previous-balance") |> render =~ "420,50"
      assert live |> element("#transaction-#{today.id}") |> render =~ "200,00"
      assert live |> element("#next-balance") |> render =~ "620,50"

      live
      |> element("button", "<<")
      |> render_click()

      assert live |> element("#previous-balance") |> render =~ "120,50"
      assert live |> element("#transaction-#{last_month.id}") |> render =~ "300,00"
      assert live |> element("#next-balance") |> render =~ "420,50"

      live
      |> element("button", ">>")
      |> render_click()

      live
      |> element("button", ">>")
      |> render_click()

      assert live |> element("#previous-balance") |> render =~ "620,50"
      assert live |> element("#transaction-#{next_month.id}") |> render =~ "400,00"
      assert live |> element("#next-balance") |> render =~ "1.020,50"
    end

    test "navigating through months with first and last month date selected", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      live
      |> form("#dates-switch")
      |> render_change(%{
        "date_start" => "2023-11-01",
        "date_end" => "2023-11-30"
      })

      assert live |> element("#previous-balance") |> render =~ "31/10/2023"
      assert live |> element("#next-balance") |> render =~ "30/11/2023"

      live
      |> element("button", ">>")
      |> render_click()

      assert live |> element("#previous-balance") |> render =~ "30/11/2023"
      assert live |> element("#next-balance") |> render =~ "31/12/2023"

      live
      |> element("button", "<<")
      |> render_click()

      assert live |> element("#previous-balance") |> render =~ "31/10/2023"
      assert live |> element("#next-balance") |> render =~ "30/11/2023"

      live
      |> form("#dates-switch")
      |> render_change(%{
        "date_start" => "2023-10-28",
        "date_end" => "2023-11-28"
      })

      assert live |> element("#previous-balance") |> render =~ "27/10/2023"
      assert live |> element("#next-balance") |> render =~ "28/11/2023"

      live
      |> element("button", ">>")
      |> render_click()

      assert live |> element("#previous-balance") |> render =~ "27/11/2023"
      assert live |> element("#next-balance") |> render =~ "28/12/2023"

      live
      |> element("button", "<<")
      |> render_click()

      assert live |> element("#previous-balance") |> render =~ "27/10/2023"
      assert live |> element("#next-balance") |> render =~ "28/11/2023"
    end

    test "shows tooltip for categories when category is child", %{
      conn: conn,
      category: category
    } do
      category = category_fixture(%{name: "child", parent: category})

      %{id: id} =
        transaction_fixture(%{
          regular: %{description: "some", category_id: category.id}
        })

      {:ok, live, _html} = live(conn, ~p"/")

      assert live |> has_element?("#category-detail-#{id}")
    end

    test "select children categories when filtering by a parent category", %{
      conn: conn
    } do
      categories = Transactions.list_categories()

      category_saude =
        categories
        |> Enum.find(&(&1.name == "Saúde"))

      category_farmacia =
        categories
        |> Enum.find(&(&1.name == "Farmácia"))

      category_consultas =
        categories
        |> Enum.find(&(&1.name == "Consultas"))

      {:ok, live, _html} = live(conn, ~p"/")

      live
      |> element("[phx-click='toggle-category'][phx-value-category-id='#{category_saude.id}']")
      |> render_click(%{"value" => "on"})

      render(live)

      assert live
             |> element("[phx-value-category-id='#{category_farmacia.id}']")
             |> render() =~ "checked"

      assert live
             |> element("[phx-value-category-id='#{category_consultas.id}']")
             |> render() =~ "checked"
    end
  end

  describe "recurrencies" do
    test "create transaction with recurrency", %{conn: conn, account: account, category: category} do
      {:ok, live, _html} = live(conn, ~p"/")

      live
      |> element("a[href='#{~p"/transactions/new"}']")
      |> render_click()

      live
      |> form("#transaction-form",
        form: %{
          date: Timex.today() |> Timex.format!("{YYYY}-{0M}-{0D}"),
          regular: %{
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
      |> form("#transaction-form",
        form: %{
          date: Timex.today() |> Timex.format!("{YYYY}-{0M}-{0D}"),
          regular: %{
            description: "a description",
            category_id: category.id
          },
          account_id: account.id,
          value: "200",
          is_recurrency: true,
          recurrency: %{
            type: :forever,
            frequency: :monthly
          }
        }
      )
      |> render_submit()

      refute live |> element("#transaction-form") |> has_element?

      transaction = Repo.one(Budget.Transactions.Transaction)

      assert live |> element("#previous-balance") |> render =~ "120,50"
      assert live |> element("#transaction-#{transaction.id}") |> render =~ "200,00"
      assert live |> element("#next-balance") |> render =~ "320,50"

      live
      |> element("button", ">>")
      |> render_click()

      recurrency = Repo.one(Budget.Transactions.Recurrency)

      next_month_transaction = Timex.today() |> Timex.shift(months: 1) |> Date.to_iso8601()

      assert live |> element("#previous-balance") |> render =~ "320,50"

      assert live
             |> element("#transaction-recurrency-#{recurrency.id}-#{next_month_transaction}-0")
             |> render =~
               "200,00"

      assert live |> element("#next-balance") |> render =~ "520,50"
    end

    test "edit existing transaction from recurrency", %{conn: conn} do
      recurrency = recurrency_fixture()

      {:ok, live, _html} = live(conn, ~p"/")

      live
      |> element("a", "Transaction description")
      |> render_click()

      live
      |> form("#transaction-form",
        form: %{
          regular: %{
            description: "a new description"
          },
          value: "420"
        }
      )
      |> render_submit()

      updated =
        recurrency.id
        |> Transactions.get_recurrency!()
        |> then(& &1.recurrency_transactions)
        |> Enum.at(0)
        |> then(& &1.transaction.id)
        |> Transactions.get_transaction!()

      assert updated.value == Decimal.new(420)
      assert updated.originator_regular.description == "a new description"
    end

    test "edit transient transaction from recurrency", %{conn: conn} do
      recurrency = recurrency_fixture()
      another_category = category_fixture()

      {:ok, live, _html} = live(conn, ~p"/")

      live
      |> element("button", ">>")
      |> render_click()

      live
      |> element("a", "Transaction description")
      |> render_click()

      live
      |> form("#transaction-form",
        form: %{
          date: ~D[2020-06-13],
          regular: %{
            description: "a new description",
            category_id: another_category.id
          },
          value: "420"
        }
      )
      |> render_submit()

      recurrency = Transactions.get_recurrency!(recurrency.id)

      assert length(recurrency.recurrency_transactions) == 2

      recurrency_transaction =
        Enum.find(recurrency.recurrency_transactions, &(&1.transaction.value == Decimal.new(420)))

      transaction = recurrency_transaction.transaction

      assert transaction.originator_regular.description == "a new description"
      assert recurrency_transaction.original_date == Timex.today() |> Timex.shift(months: 1)
      assert transaction.date == ~D[2020-06-13]
    end

    test "edit a persistent transaction from recurrency", %{conn: conn} do
      recurrency = recurrency_fixture()

      {:ok, %{id: id}} =
        recurrency.id
        |> Transactions.get_recurrency!()
        |> Transactions.recurrency_transactions(Timex.today() |> Timex.shift(months: 3))
        |> Enum.at(0)
        |> Transactions.Transaction.Form.apply_update(%{})

      {:ok, live, _html} = live(conn, ~p"/")

      live
      |> element("button", ">>")
      |> render_click()

      live
      |> element("a", "Transaction description")
      |> render_click()

      path = assert_patch(live)
      assert path == ~p"/transactions/#{id}/edit"

      live
      |> form("#transaction-form",
        form: %{
          date: ~D[2020-06-13],
          regular: %{
            description: "a new description"
          },
          value: "420"
        }
      )
      |> render_submit()

      recurrency = Transactions.get_recurrency!(recurrency.id)

      assert length(recurrency.recurrency_transactions) == 2

      transaction = Transactions.get_transaction!(id)

      assert transaction.originator_regular.description == "a new description"
      assert transaction.date == ~D[2020-06-13]
      assert transaction.value == Decimal.new(420)
    end

    test "apply changes forward", %{conn: conn} do
      %{id: id} = recurrency_fixture()

      {:ok, live, _html} = live(conn, ~p"/")

      live
      |> element("button", ">>")
      |> render_click()

      assert_query(
        assert_patch(live, 100), 
        "/",
        from: "date",
        date_start: Timex.today() |> Timex.shift(months: 1) |> Timex.beginning_of_month(),
        date_end: Timex.today() |> Timex.shift(months: 1) |> Timex.end_of_month()
      )

      live
      |> element("button", ">>")
      |> render_click()

      assert_query(
        assert_patch(live, 100), 
        "/",
        from: "date",
        date_start: Timex.today() |> Timex.shift(months: 2) |> Timex.beginning_of_month(),
        date_end: Timex.today() |> Timex.shift(months: 2) |> Timex.end_of_month()
      )

      live
      |> element("a", "Transaction description")
      |> render_click()

      recurrency_to_edit = Timex.today() |> Timex.shift(months: 2) |> Date.to_iso8601()

      assert_query(
        assert_patch(live, 100), 
        "/transactions/recurrency-#{id}-#{recurrency_to_edit}-0/edit",
        from: "date",
        date_start: Timex.today() |> Timex.shift(months: 2) |> Timex.beginning_of_month(),
        date_end: Timex.today() |> Timex.shift(months: 2) |> Timex.end_of_month()
      )

      live
      |> form("#transaction-form",
        form: %{
          value: "420",
          apply_forward: true
        }
      )
      |> render_submit()

      assert_query(
        assert_patch(live, 100), 
        "/",
        from: "transaction",
        date_start: Timex.today() |> Timex.shift(months: 2) |> Timex.beginning_of_month(),
        date_end: Timex.today() |> Timex.shift(months: 2) |> Timex.end_of_month()
      )

      live
      |> element("button", ">>")
      |> render_click()

      assert_query(
        assert_patch(live, 100), 
        "/",
        from: "date",
        date_start: Timex.today() |> Timex.shift(months: 3) |> Timex.beginning_of_month(),
        date_end: Timex.today() |> Timex.shift(months: 3) |> Timex.end_of_month()
      )

      assert live |> element("[id^=transaction-recurrency]") |> render =~ "420,00"

      live
      |> element("button", "<<")
      |> render_click()

      assert_query(
        assert_patch(live, 100), 
        "/",
        from: "date",
        date_start: Timex.today() |> Timex.shift(months: 2) |> Timex.beginning_of_month(),
        date_end: Timex.today() |> Timex.shift(months: 2) |> Timex.end_of_month()
      )

      live
      |> element("button", "<<")
      |> render_click()

      assert_query(
        assert_patch(live, 100), 
        "/",
        from: "date",
        date_start: Timex.today() |> Timex.shift(months: 1) |> Timex.beginning_of_month(),
        date_end: Timex.today() |> Timex.shift(months: 1) |> Timex.end_of_month()
      )

      assert live |> element("[id^=transaction-recurrency]") |> render =~ "133,00"
    end
  end

  test "delete single transaction", %{conn: conn, account: account} do
    transaction = transaction_fixture(%{account_id: account.id})

    {:ok, live, _html} = live(conn, ~p"/")

    live
    |> element("[data-testid=delete-#{transaction.id}]")
    |> render_click()

    assert live
           |> element("button", "Yes")
           |> render_click() =~ "Transaction successfully deleted!"
  end

  test "delete recurrent transaction and the next transient one", %{conn: conn} do
    recurrency = recurrency_fixture()

    transaction = recurrency.recurrency_transactions |> Enum.at(0) |> then(& &1.transaction)

    {:ok, live, html} = live(conn, ~p"/")

    assert html =~ "Transaction description"

    html =
      live
      |> element("[data-testid=delete-#{transaction.id}]")
      |> render_click()

    assert html =~ "Delete just this transaction"
    assert html =~ "Delete this transaction and future transactions"

    html =
      live
      |> element("button", "Delete just this transaction")
      |> render_click()

    assert html =~ "Transaction successfully deleted!"
    refute html =~ "Transaction description"
  end

  test "delete recurrent transient transaction", %{conn: conn} do
    recurrency_fixture()

    {:ok, live, _html} = live(conn, ~p"/")

    html =
      live
      |> element("button", ">>")
      |> render_click()

    assert html =~ "Transaction description"

    html =
      live
      |> element("[data-testid^=delete-]")
      |> render_click()

    assert html =~ "Delete just this transaction"
    assert html =~ "Delete this transaction and future transactions"

    html =
      live
      |> element("button", "Delete this transaction and future transactions")
      |> render_click()

    assert html =~ "Transaction successfully deleted!"
    refute html =~ "Transaction description"

    html =
      live
      |> element("button", ">>")
      |> render_click()

    refute html =~ "Transaction description"
  end

  test "delete recurrent transient with future persisted", %{conn: conn} do
    recurrency_fixture()

    {:ok, live, _html} = live(conn, ~p"/")

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
    |> element("a", "Transaction description")
    |> render_click()

    live
    |> form("#transaction-form")
    |> render_submit()

    html = render(live)

    assert html =~ "Transaction updated successfully!"

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

    assert html =~ "Delete just this transaction"
    assert html =~ "Delete this transaction with future ones but keep changed ones"
    assert html =~ "Delete this transaction and all future ones"

    html =
      live
      |> element("button", "Delete this transaction with future ones but keep changed ones")
      |> render_click()

    assert html =~ "Transaction successfully deleted!"

    refute live
           |> element("button", ">>")
           |> render_click() =~ "Transaction description"

    assert live
           |> element("button", ">>")
           |> render_click() =~ "Transaction description"
  end

  test "create new category", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/")

    live
    |> element("a[href='#{~p"/categories/new"}']")
    |> render_click()

    live
    |> form("#category-form", category: %{name: "test category"})
    |> render_submit()

    html = render(live)

    assert html =~ "Category created successfully"
    assert html =~ "test category"
  end

  test "create new child category", %{conn: conn, category: category} do
    {:ok, live, _html} = live(conn, ~p"/")

    live
    |> element("a[href='#{~p"/categories/#{category}/children/new"}']")
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
    {:ok, live, _html} = live(conn, ~p"/")

    live
    |> element("a[href='#{~p"/categories/#{category}/edit"}']")
    |> render_click()

    live
    |> form("#category-form", category: %{name: "another category name"})
    |> render_submit()

    html = render(live)

    assert html =~ "Category updated successfully"
    assert html =~ "another category name"
  end

  test "reordering elements", %{
    conn: conn,
    category: %{id: category_id},
    account: %{id: account_id}
  } do
    1..5
    |> Enum.map(
      &transaction_fixture(%{
        regular: %{
          description: "Transaction #{&1}",
          category_id: category_id
        },
        account_id: account_id
      })
    )

    {:ok, live, html} = live(conn, ~p"/")

    assert html =~
             ~r/Transaction 1[\s\S]*Transaction 2[\s\S]*Transaction 3[\s\S]*Transaction 4[\s\S]*Transaction 5/

    render_hook(live, "reorder", %{"newIndex" => 1, "oldIndex" => 4})

    assert render(live) =~
             ~r/Transaction 1[\s\S]*Transaction 5[\s\S]*Transaction 2[\s\S]*Transaction 3[\s\S]*Transaction 4/
  end

  test "toggles previous balance", %{conn: conn} do
    %{id: id} = transaction_fixture()

    {:ok, live, _html} = live(conn, ~p"/")

    refute live
           |> element("#transaction-#{id}")
           |> render() =~ "374,00"

    assert live
           |> element("#previous-balance")
           |> render() =~ "241,00"

    assert live
           |> element("#next-balance")
           |> render() =~ "374,00"

    live
    |> element("[phx-click='toggle-previous-balance']")
    |> render_click()

    assert live
           |> element("#previous-balance")
           |> render() =~ "0,00"

    assert live
           |> element("#next-balance")
           |> render() =~ "133,00"

    live
    |> element("[phx-click='toggle-partial-balance']")
    |> render_click()

    live
    |> element("[phx-click='toggle-previous-balance']")
    |> render_click()

    assert live
           |> element("#transaction-#{id}")
           |> render() =~ "374,00"
  end

  test "editing a recurrency transfer shows correct accounts", %{
    conn: conn,
    category: category,
    account: account
  } do
    account_a = account_fixture(%{name: "A"})
    account_b = account_fixture(%{name: "B"})

    recurrency =
      recurrency_fixture(%{
        date: ~D[2022-01-01],
        account_id: account.id,
        value: 200,
        originator: "transfer",
        transfer: %{
          other_account_id: account_b.id
        }
      })

    {:ok, live, _html} =
      live(
        conn,
        ~p"/transactions/#{"recurrency-" <> to_string(recurrency.id) <> "-2022-02-01-0"}/edit"
      )

    assert live
           |> element("#form_transfer_0_other_account_id > option", "B")
           |> render() =~ "selected"

    {:ok, live, _html} =
      live(
        conn,
        ~p"/transactions/#{"recurrency-" <> to_string(recurrency.id) <> "-2022-02-01-1"}/edit"
      )

    assert live
           |> element("#form_transfer_0_other_account_id > option", "Account Name")
           |> render() =~ "selected"
  end


  def assert_query(url, path, search_params) do
    uri = url |> URI.parse()
    query = uri |> Map.get(:query) |> URI.decode_query()

    assert path == uri.path

    search_params 
    |> Enum.each(fn {key, value} -> 
      against = Map.get(query, to_string(key))

      case value do
        %Date{} -> assert against == Date.to_iso8601(value)
        _ -> assert against == value
      end
    end)

    
  end
end

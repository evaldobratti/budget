defmodule Budget.TransactionsTest do
  use Budget.DataCase, async: true

  alias Budget.Transactions.Originator.Transfer
  alias Budget.Transactions.Originator.Regular
  alias Budget.Transactions
  alias Budget.Transactions.Recurrency
  alias Budget.Transactions.Transaction
  alias Budget.Transactions.Category

  import Budget.TransactionsFixtures

  def create_account(_) do
    {:ok, account1} =
      Transactions.create_account(%{
        name: "Account name",
        initial_balance: -10
      })

    {:ok, account2} =
      Transactions.create_account(%{
        name: "Account name",
        initial_balance: 50
      })

    %{account1: account1, account2: account2}
  end

  describe "change_recurrency/2" do
    setup :create_account

    test "finite recurrency", %{account1: account} do
      changeset =
        Transactions.change_recurrency(%Recurrency{}, %{
          date_start: "2022-10-01",
          date_end: "2022-10-01",
          account_id: account.id,
          is_forever: false,
          is_parcel: false,
          frequency: :monthly,
          transaction_payload: %{
            originator_regular: %{
              description: "Some description",
              category_id: category_fixture().id
            },
            value: 200
          }
        })

      assert %{valid?: true} = changeset

      changeset =
        Transactions.change_recurrency(%Recurrency{}, %{
          date_start: "2022-10-01",
          account_id: account.id,
          is_forever: false,
          is_parcel: false,
          frequency: :monthly,
          transaction_payload: %{
            originator_regular: %{
              description: "Some description",
              category_id: category_fixture().id
            },
            value: 200
          }
        })

      assert %{valid?: false} = changeset
      assert errors_on(changeset).date_end == ["can't be blank"]
    end

    test "infinite recurrency", %{account1: account} do
      changeset =
        Transactions.change_recurrency(%Recurrency{}, %{
          date_start: "2022-10-01",
          date_end: "2022-10-01",
          value: "200",
          account_id: account.id,
          is_forever: true,
          is_parcel: false,
          frequency: :monthly,
          transaction_payload: %{
            originator_regular: %{
              description: "Some description",
              category_id: category_fixture().id
            },
            value: "200"
          }
        })

      assert %{valid?: true, changes: changes} = changeset
      assert Map.get(changes, :date_end) == nil
    end

    test "infinite parcel", %{account1: account} do
      changeset =
        Transactions.change_recurrency(%Recurrency{}, %{
          date_start: "2022-10-01",
          date_end: "2022-10-01",
          account_id: account.id,
          is_forever: true,
          is_parcel: true,
          frequency: :monthly,
          transaction_payload: %{
            originator_regular: %{
              description: "Some description",
              category_id: category_fixture().id
            },
            value: "200"
          }
        })

      assert %{valid?: false} = changeset
      assert errors_on(changeset).is_forever == ["Recurrency can't be infinite parcel"]
    end

    test "parcel", %{account1: account} do
      changeset =
        Transactions.change_recurrency(%Recurrency{}, %{
          date_start: "2022-10-01",
          is_forever: false,
          is_parcel: true,
          frequency: :monthly,
          account_id: account.id,
          transaction_payload: %{
            originator_regular: %{
              description: "Some description",
              category_id: category_fixture().id
            },
            value: "200"
          }
        })

      assert %{valid?: false} = changeset

      assert errors_on(changeset) == %{
               parcel_start: ["can't be blank"],
               parcel_end: ["can't be blank"]
             }
    end

    test "calculate finite recurrency transactions until date - monthly" do
      recurrency =
        recurrency_fixture(%{
          date: ~D[2019-01-01],
          regular: %{
            description: "Some description",
            category_id: category_fixture().id
          },
          value: 200,
          recurrency: %{
            is_forever: false,
            frequency: :monthly,
            date_end: ~D[2019-03-31]
          }
        })

      assert [
               %{date: ~D[2019-02-01], value: 200, description: "Some description"},
               %{date: ~D[2019-03-01], value: 200, description: "Some description"}
             ] =
               Transactions.recurrency_transactions(recurrency, ~D[2019-03-15])
               |> Enum.map(
                 &%{
                   date: &1.date,
                   value: Decimal.to_integer(&1.value),
                   description: &1.originator_regular.description
                 }
               )

      assert [
               %{date: ~D[2019-02-01], value: 200, description: "Some description"},
               %{date: ~D[2019-03-01], value: 200, description: "Some description"}
             ] =
               Transactions.recurrency_transactions(recurrency, ~D[2019-03-01])
               |> Enum.map(
                 &%{
                   date: &1.date,
                   value: Decimal.to_integer(&1.value),
                   description: &1.originator_regular.description
                 }
               )

      assert [] = Transactions.recurrency_transactions(recurrency, ~D[2018-03-01])

      assert [
               %{date: ~D[2019-02-01], value: 200, description: "Some description"},
               %{date: ~D[2019-03-01], value: 200, description: "Some description"}
             ] =
               Transactions.recurrency_transactions(recurrency, ~D[2019-06-01])
               |> Enum.map(
                 &%{
                   date: &1.date,
                   value: Decimal.to_integer(&1.value),
                   description: &1.originator_regular.description
                 }
               )
    end

    test "calculate finite recurrency transactions until date - weekly" do
      recurrency =
        recurrency_fixture(%{
          date: ~D[2019-01-01],
          regular: %{
            description: "Some description",
            category_id: category_fixture().id
          },
          value: 200,
          recurrency: %{
            is_forever: false,
            frequency: :weekly,
            value: 200,
            date_end: ~D[2019-01-31]
          }
        })

      assert [
               %{date: ~D[2019-01-08], value: 200, description: "Some description"},
               %{date: ~D[2019-01-15], value: 200, description: "Some description"},
               %{date: ~D[2019-01-22], value: 200, description: "Some description"},
               %{date: ~D[2019-01-29], value: 200, description: "Some description"}
             ] =
               Transactions.recurrency_transactions(recurrency, ~D[2019-03-15])
               |> Enum.map(
                 &%{
                   date: &1.date,
                   value: Decimal.to_integer(&1.value),
                   description: &1.originator_regular.description
                 }
               )

      assert [
               %{date: ~D[2019-01-08], value: 200, description: "Some description"},
               %{date: ~D[2019-01-15], value: 200, description: "Some description"}
             ] =
               Transactions.recurrency_transactions(recurrency, ~D[2019-01-15])
               |> Enum.map(
                 &%{
                   date: &1.date,
                   value: Decimal.to_integer(&1.value),
                   description: &1.originator_regular.description
                 }
               )

      assert [] = Transactions.recurrency_transactions(recurrency, ~D[2018-03-01])

      assert [
               %{date: ~D[2019-01-08], value: 200, description: "Some description"},
               %{date: ~D[2019-01-15], value: 200, description: "Some description"},
               %{date: ~D[2019-01-22], value: 200, description: "Some description"},
               %{date: ~D[2019-01-29], value: 200, description: "Some description"}
             ] =
               Transactions.recurrency_transactions(recurrency, ~D[2019-06-01])
               |> Enum.map(
                 &%{
                   date: &1.date,
                   value: Decimal.to_integer(&1.value),
                   description: &1.originator_regular.description
                 }
               )
    end

    test "calculate infinite recurrency transactions starting date 31" do
      recurrency =
        recurrency_fixture(%{
          date: ~D[2019-01-31],
          recurrency: %{
            is_forever: false,
            frequency: :monthly,
            date_end: ~D[2020-01-31]
          }
        })

      assert [
               ~D[2019-02-28],
               ~D[2019-03-31],
               ~D[2019-04-30],
               ~D[2019-05-31],
               ~D[2019-06-30],
               ~D[2019-07-31]
             ] ==
               recurrency
               |> Transactions.recurrency_transactions(~D[2019-07-31])
               |> Enum.map(& &1.date)
    end

    test "calculate parcel weekly 1 to 6" do
      recurrency =
        recurrency_fixture(%{
          date: ~D[2019-01-01],
          regular: %{
            description: "Some description",
            category_id: category_fixture().id
          },
          value: 200,
          recurrency: %{
            is_forever: false,
            is_parcel: true,
            frequency: :weekly,
            parcel_start: 1,
            parcel_end: 6
          }
        })

      assert [
               %{
                 date: ~D[2019-01-08],
                 value: 200,
                 description: "Some description",
                 parcel: 2,
                 parcel_end: 6
               },
               %{
                 date: ~D[2019-01-15],
                 value: 200,
                 description: "Some description",
                 parcel: 3,
                 parcel_end: 6
               },
               %{
                 date: ~D[2019-01-22],
                 value: 200,
                 description: "Some description",
                 parcel: 4,
                 parcel_end: 6
               },
               %{
                 date: ~D[2019-01-29],
                 value: 200,
                 description: "Some description",
                 parcel: 5,
                 parcel_end: 6
               },
               %{
                 date: ~D[2019-02-05],
                 value: 200,
                 description: "Some description",
                 parcel: 6,
                 parcel_end: 6
               }
             ] =
               Transactions.recurrency_transactions(recurrency, ~D[2019-04-01])
               |> Enum.map(
                 &%{
                   date: &1.date,
                   value: Decimal.to_integer(&1.value),
                   description: &1.originator_regular.description,
                   parcel: &1.recurrency_transaction.parcel,
                   parcel_end: &1.recurrency_transaction.parcel_end
                 }
               )

      assert [
               %{
                 date: ~D[2019-01-08],
                 value: 200,
                 description: "Some description",
                 parcel: 2,
                 parcel_end: 6
               },
               %{
                 date: ~D[2019-01-15],
                 value: 200,
                 description: "Some description",
                 parcel: 3,
                 parcel_end: 6
               },
               %{
                 date: ~D[2019-01-22],
                 value: 200,
                 description: "Some description",
                 parcel: 4,
                 parcel_end: 6
               }
             ] =
               Transactions.recurrency_transactions(recurrency, ~D[2019-01-22])
               |> Enum.map(
                 &%{
                   date: &1.date,
                   value: Decimal.to_integer(&1.value),
                   description: &1.originator_regular.description,
                   parcel: &1.recurrency_transaction.parcel,
                   parcel_end: &1.recurrency_transaction.parcel_end
                 }
               )
    end

    test "calculate parcel weekly 3 to 6" do
      recurrency =
        recurrency_fixture(%{
          date: ~D[2019-01-01],
          regular: %{
            description: "Some description",
            category_id: category_fixture().id
          },
          value: 200,
          recurrency: %{
            is_forever: false,
            is_parcel: true,
            frequency: :weekly,
            parcel_start: 3,
            parcel_end: 6
          }
        })

      assert [
               %{date: ~D[2019-01-08], value: 200, parcel: 4, parcel_end: 6},
               %{date: ~D[2019-01-15], value: 200, parcel: 5, parcel_end: 6},
               %{date: ~D[2019-01-22], value: 200, parcel: 6, parcel_end: 6}
             ] =
               Transactions.recurrency_transactions(recurrency, ~D[2019-04-01])
               |> Enum.map(
                 &%{
                   date: &1.date,
                   value: Decimal.to_integer(&1.value),
                   parcel: &1.recurrency_transaction.parcel,
                   parcel_end: &1.recurrency_transaction.parcel_end
                 }
               )

      assert [
               %{date: ~D[2019-01-08], value: 200, parcel: 4, parcel_end: 6},
               %{date: ~D[2019-01-15], value: 200, parcel: 5, parcel_end: 6}
             ] =
               Transactions.recurrency_transactions(recurrency, ~D[2019-01-15])
               |> Enum.map(
                 &%{
                   date: &1.date,
                   value: Decimal.to_integer(&1.value),
                   parcel: &1.recurrency_transaction.parcel,
                   parcel_end: &1.recurrency_transaction.parcel_end
                 }
               )
    end

    test "recurrency when it ends and the end of an transaction" do
      recurrency =
        recurrency_fixture(%{
          date: ~D[2019-01-01],
          recurrency: %{
            is_forever: false,
            description: "Some description",
            frequency: :monthly,
            value: 200,
            date_end: ~D[2019-03-01]
          }
        })

      assert [
               %{date: ~D[2019-02-01]},
               %{date: ~D[2019-03-01]}
             ] = Transactions.recurrency_transactions(recurrency, ~D[2019-03-03])
    end
  end

  describe "transactions_in_period/3" do
    setup :create_account

    test "retrieve regular transactions", %{account1: account} do
      category1 = category_fixture()
      category2 = category_fixture()

      {:ok, _} =
        Transaction.Form.apply_insert(%{
          date: ~D[2020-01-31],
          originator: "regular",
          regular: %{
            description: "Description2",
            category_id: category1.id
          },
          account_id: account.id,
          value: 200
        })

      {:ok, _} =
        Transaction.Form.apply_insert(%{
          date: ~D[2020-02-01],
          originator: "regular",
          regular: %{
            description: "Description1",
            category_id: category1.id
          },
          account_id: account.id,
          value: 200
        })

      {:ok, _} =
        Transaction.Form.apply_insert(%{
          date: ~D[2020-02-10],
          originator: "regular",
          regular: %{
            description: "Description3",
            category_id: category1.id
          },
          account_id: account.id,
          value: 200
        })

      {:ok, _} =
        Transaction.Form.apply_insert(%{
          date: ~D[2020-02-11],
          originator: "regular",
          regular: %{
            description: "Description4",
            category_id: category2.id
          },
          account_id: account.id,
          value: 200
        })

      transactions =
        Transactions.transactions_in_period(~D[2020-02-01], ~D[2020-02-10],
          account_ids: [account.id]
        )

      assert length(transactions) == 2

      transactions = Transactions.transactions_in_period(~D[2020-02-01], ~D[2020-02-10])
      assert length(transactions) == 2

      transactions =
        Transactions.transactions_in_period(~D[2020-02-01], ~D[2020-02-12],
          category_ids: [category1.id]
        )

      assert length(transactions) == 2

      transactions =
        Transactions.transactions_in_period(~D[2020-02-01], ~D[2020-02-12],
          category_ids: [category2.id]
        )

      assert length(transactions) == 1
    end

    test "retrieve recurrency transactions", %{account1: account} do
      category = category_fixture()

      {:ok, _transaction} =
        Transaction.Form.apply_insert(%{
          date: ~D[2020-02-01],
          account_id: account.id,
          originator: "regular",
          regular: %{
            description: "Description1",
            category_id: category.id
          },
          value: 200,
          recurrency: %{
            is_parcel: false,
            date_start: ~D[2020-02-01],
            date_end: ~D[2021-02-01],
            frequency: :monthly,
            is_forever: false,
            account_id: account.id
          }
        })

      transactions = Transactions.transactions_in_period(~D[2020-01-01], ~D[2020-04-10])

      value = Decimal.new(200)

      assert [
               %Transaction{
                 date: ~D[2020-02-01],
                 originator_regular: %{description: "Description1"},
                 value: ^value
               },
               %{
                 date: ~D[2020-03-01],
                 originator_regular: %{description: "Description1"},
                 value: ^value
               },
               %{
                 date: ~D[2020-04-01],
                 originator_regular: %{description: "Description1"},
                 value: ^value
               }
             ] = transactions
    end
  end

  describe "balance_at/2" do
    setup :create_account

    test "balance with only initial balance", %{account1: account1, account2: account2} do
      balance = Transactions.balance_at(~D[2020-01-01], account_ids: [account1.id, account2.id])

      assert balance == Decimal.new(40)
    end

    test "balance with transactions", %{account1: account1, account2: account2} do
      category1 = category_fixture()
      category2 = category_fixture()

      {:ok, _} =
        Transaction.Form.apply_insert(%{
          date: ~D[2020-01-05],
          originator: "regular",
          regular: %{
            description: "Description",
            category_id: category1.id
          },
          account_id: account1.id,
          value: 200
        })

      {:ok, _} =
        Transaction.Form.apply_insert(%{
          date: ~D[2020-01-05],
          originator: "regular",
          regular: %{
            description: "Description",
            category_id: category2.id
          },
          account_id: account2.id,
          value: 100
        })

      assert Transactions.balance_at(~D[2020-01-04], account_ids: [account1.id, account2.id]) ==
               Decimal.new(40)

      assert Transactions.balance_at(~D[2020-01-05], account_ids: [account1.id, account2.id]) ==
               Decimal.new(340)

      assert Transactions.balance_at(~D[2020-01-04], account_ids: []) == Decimal.new(40)
      assert Transactions.balance_at(~D[2020-01-05], account_ids: []) == Decimal.new(340)

      assert Transactions.balance_at(~D[2020-01-04], account_ids: [account1.id]) ==
               Decimal.new(-10)

      assert Transactions.balance_at(~D[2020-01-05], account_ids: [account1.id]) ==
               Decimal.new(190)

      assert Transactions.balance_at(~D[2020-01-04], category_ids: [category1.id, category2.id]) ==
               Decimal.new(40)

      assert Transactions.balance_at(~D[2020-01-05], category_ids: [category1.id, category2.id]) ==
               Decimal.new(340)

      assert Transactions.balance_at(~D[2020-01-04], category_ids: []) == Decimal.new(40)
      assert Transactions.balance_at(~D[2020-01-05], category_ids: []) == Decimal.new(340)

      assert Transactions.balance_at(~D[2020-01-04], category_ids: [category2.id]) ==
               Decimal.new(40)

      assert Transactions.balance_at(~D[2020-01-05], category_ids: [category2.id]) ==
               Decimal.new(140)

      assert Transactions.balance_at(~D[2020-01-04],
               account_ids: [account1.id],
               category_ids: [category1.id]
             ) == Decimal.new(-10)

      assert Transactions.balance_at(~D[2020-01-05],
               account_ids: [account1.id],
               category_ids: [category1.id]
             ) == Decimal.new(190)
    end

    test "balance with recurrencies", %{account1: account} do
      category = category_fixture()

      recurrency_fixture(%{
        date: ~D[2020-02-01],
        account_id: account.id,
        value: 200,
        originator_regular: %{
          description: "something",
          category_id: category.id
        },
        recurrency_transaction: %{
          recurrency: %{
            date_start: ~D[2020-02-01],
            date_end: ~D[2021-02-01],
            frequency: :monthly,
            is_forever: false,
            value: 200,
            transaction_payload: %{
              value: 200,
              originator_regular: %{
                description: "something",
                category_id: category.id
              }
            }
          }
        }
      })

      balance = Transactions.balance_at(~D[2020-06-01], [])

      assert balance == Decimal.new(1040)
    end
  end

  describe "create_transient_transaction/2" do
    test "create transaction and recurrency_transaction" do
      recurrency = recurrency_fixture()

      transient_transactions =
        Transactions.recurrency_transactions(
          recurrency,
          Timex.today() |> Timex.shift(months: 3)
        )

      assert length(transient_transactions) == 3

      {:ok, created} = Transaction.Form.apply_update(Enum.at(transient_transactions, 1), %{})

      assert created.recurrency_transaction.original_date ==
               Timex.today() |> Timex.shift(months: 2)

      transient_transactions =
        recurrency.id
        |> Transactions.get_recurrency!()
        |> Transactions.recurrency_transactions(Timex.today() |> Timex.shift(months: 3))

      assert length(transient_transactions) == 2
    end

    test "updating a transient transaction applying changes forward" do
      recurrency = recurrency_fixture(%{date: ~D[2022-10-15]})

      [_, transient | _] = Transactions.recurrency_transactions(recurrency, ~D[2022-12-15])

      assert "recurrency" <> _ = transient.id
      assert transient.date == ~D[2022-12-15]
      assert transient.value == Decimal.new(133)
      assert transient.originator_regular.category_id > 0

      {:ok, _} = Transaction.Form.apply_update(transient, %{value: 500, apply_forward: true})

      transactions =
        Transactions.transactions_in_period(~D[2022-10-15], ~D[2023-10-15],
          account_ids: [transient.account_id]
        )

      assert %{date: ~D[2022-10-15], value: Decimal.new(133)} ==
               Enum.at(transactions, 0) |> Map.take([:date, :value])

      assert %{date: ~D[2022-11-15], value: Decimal.new(133)} ==
               Enum.at(transactions, 1) |> Map.take([:date, :value])

      assert %{date: ~D[2022-12-15], value: Decimal.new(500)} ==
               Enum.at(transactions, 2) |> Map.take([:date, :value])

      assert %{date: ~D[2023-01-15], value: Decimal.new(500)} ==
               Enum.at(transactions, 3) |> Map.take([:date, :value])

      assert %{date: ~D[2023-02-15], value: Decimal.new(500)} ==
               Enum.at(transactions, 4) |> Map.take([:date, :value])

      assert %{date: ~D[2023-03-15], value: Decimal.new(500)} ==
               Enum.at(transactions, 5) |> Map.take([:date, :value])

      assert %{date: ~D[2023-04-15], value: Decimal.new(500)} ==
               Enum.at(transactions, 6) |> Map.take([:date, :value])
    end

    test "updating a transient transaction from parcel applying changes forward" do
      recurrency =
        recurrency_fixture(%{
          date: ~D[2022-10-15],
          recurrency: %{
            is_forever: false,
            is_parcel: true,
            parcel_start: 1,
            parcel_end: 6
          }
        })

      [_, transient | _] = Transactions.recurrency_transactions(recurrency, ~D[2022-12-15])

      assert "recurrency" <> _ = transient.id
      assert transient.date == ~D[2022-12-15]
      assert transient.value == Decimal.new(133)
      assert transient.originator_regular.description == "Transaction description"
      assert transient.recurrency_transaction.parcel == 3
      assert transient.recurrency_transaction.parcel_end == 6
      assert transient.position == Decimal.new(999_999)

      {:ok, _} = Transaction.Form.apply_update(transient, %{value: 500, apply_forward: true})

      transactions =
        Transactions.transactions_in_period(~D[2022-10-15], ~D[2023-10-15],
          account_ids: [transient.account_id]
        )

      assert %{
               date: ~D[2022-10-15],
               value: Decimal.new(133),
               description: "Transaction description",
               parcel: 1
             } ==
               Enum.at(transactions, 0)
               |> then(
                 &%{
                   date: &1.date,
                   value: &1.value,
                   description: &1.originator_regular.description,
                   parcel: &1.recurrency_transaction.parcel
                 }
               )

      assert %{
               date: ~D[2022-11-15],
               value: Decimal.new(133),
               description: "Transaction description",
               parcel: 2
             } ==
               Enum.at(transactions, 1)
               |> then(
                 &%{
                   date: &1.date,
                   value: &1.value,
                   description: &1.originator_regular.description,
                   parcel: &1.recurrency_transaction.parcel
                 }
               )

      assert %{
               date: ~D[2022-12-15],
               value: Decimal.new(500),
               description: "Transaction description",
               parcel: 3
             } ==
               Enum.at(transactions, 2)
               |> then(
                 &%{
                   date: &1.date,
                   value: &1.value,
                   description: &1.originator_regular.description,
                   parcel: &1.recurrency_transaction.parcel
                 }
               )

      assert %{
               date: ~D[2023-01-15],
               value: Decimal.new(500),
               description: "Transaction description",
               parcel: 4
             } ==
               Enum.at(transactions, 3)
               |> then(
                 &%{
                   date: &1.date,
                   value: &1.value,
                   description: &1.originator_regular.description,
                   parcel: &1.recurrency_transaction.parcel
                 }
               )

      assert %{
               date: ~D[2023-02-15],
               value: Decimal.new(500),
               description: "Transaction description",
               parcel: 5
             } ==
               Enum.at(transactions, 4)
               |> then(
                 &%{
                   date: &1.date,
                   value: &1.value,
                   description: &1.originator_regular.description,
                   parcel: &1.recurrency_transaction.parcel
                 }
               )

      assert %{
               date: ~D[2023-03-15],
               value: Decimal.new(500),
               description: "Transaction description",
               parcel: 6
             } ==
               Enum.at(transactions, 5)
               |> then(
                 &%{
                   date: &1.date,
                   value: &1.value,
                   description: &1.originator_regular.description,
                   parcel: &1.recurrency_transaction.parcel
                 }
               )

      assert nil == Enum.at(transactions, 6)
    end

    test "updating recurrency transaction without applying changes forward" do
      recurrency =
        recurrency_fixture(%{
          date: ~D[2022-10-15],
          recurrency: %{
            date_start: ~D[2022-10-15],
            is_forever: false,
            is_parcel: true,
            parcel_start: 1,
            parcel_end: 6
          }
        })

      [_, transient | _] = Transactions.recurrency_transactions(recurrency, ~D[2022-12-15])

      transient_date = ~D[2022-12-15]

      assert "recurrency" <> _ = transient.id
      assert transient_date == transient.date

      assert %{
               "2022-10-15" => %{
                 "category_id" => _,
                 "description" => "Transaction description",
                 "value" => "133"
               }
             } = recurrency.transaction_payload

      {:ok, _} = Transaction.Form.apply_update(transient, %{value: 500, apply_forward: false})

      assert %{
               "2022-10-15" => %{
                 "category_id" => _,
                 "description" => "Transaction description",
                 "value" => "133"
               }
             } = Transactions.get_recurrency!(recurrency.id).transaction_payload

      transactions =
        Transactions.transactions_in_period(~D[2022-10-15], ~D[2023-10-15],
          account_ids: [transient.account_id]
        )

      assert Decimal.new(133) == Enum.at(transactions, 0).value

      assert Decimal.new(133) == Enum.at(transactions, 1).value

      assert Decimal.new(500) == Enum.at(transactions, 2).value
      assert transient_date == Enum.at(transactions, 2).date

      assert Decimal.new(133) == Enum.at(transactions, 3).value
    end
  end

  describe "create_transaction/1" do
    test "create regular transaction" do
      %{id: account_id} = account_fixture()
      %{id: category_id} = category_fixture()

      assert {:ok,
              %{
                date: ~D[2022-01-01],
                account_id: ^account_id,
                originator_regular: %{
                  description: "a description",
                  category_id: ^category_id
                },
                position: position
              }} =
               Transaction.Form.apply_insert(%{
                 date: ~D[2022-01-01],
                 account_id: account_id,
                 originator: "regular",
                 regular: %{
                   description: "a description",
                   category_id: category_id
                 },
                 value: 200
               })

      assert position == Decimal.new(1)

      assert {:ok,
              %{
                position: position
              }} =
               Transaction.Form.apply_insert(%{
                 date: ~D[2022-01-01] |> Date.to_iso8601(),
                 account_id: account_id,
                 originator: "regular",
                 regular: %{
                   description: "a description",
                   category_id: category_id
                 },
                 value: 200
               })

      assert position == Decimal.new(2)
    end

    test "updates recurrency_transaction if transaction is parcel recurrency" do
      account = account_fixture()
      category = category_fixture()

      transaction = %{
        date: ~D[2020-06-01],
        account_id: account.id,
        originator: "regular",
        regular: %{
          description: "a description",
          category_id: category.id
        },
        value: 200,
        recurrency: %{
          is_forever: false,
          is_parcel: true,
          parcel_start: 1,
          parcel_end: 6,
          frequency: :monthly
        }
      }

      {:ok, transaction} = Transaction.Form.apply_insert(transaction)

      assert transaction.originator_regular.description == "a description"
      assert transaction.recurrency_transaction.parcel == 1
      assert transaction.recurrency_transaction.parcel_end == 6
    end

    test "create transfer" do
      %{id: from_account_id} = account_fixture()
      %{id: to_account_id} = account_fixture()

      assert {:ok, _} =
               Transaction.Form.apply_insert(%{
                 date: ~D[2022-01-01],
                 account_id: from_account_id,
                 originator: "transfer",
                 transfer: %{
                   other_account_id: to_account_id
                 },
                 value: 200
               })

      assert [
               {from_account_id, Decimal.new(200)},
               {to_account_id, Decimal.new(-200)}
             ] ==
               Transactions.transactions_in_period(~D[2022-01-01], ~D[2022-01-01])
               |> Enum.map(&{&1.account_id, &1.value})
    end

    test "create recurrent transfer" do
      %{id: from_account_id} = account_fixture()
      %{id: to_account_id} = account_fixture()

      assert {:ok, _} =
               Transaction.Form.apply_insert(%{
                 date: ~D[2022-01-01] |> Date.to_iso8601(),
                 account_id: from_account_id,
                 is_recurrency: true,
                 recurrency: %{
                   frequency: :monthly,
                   is_forever: true
                 },
                 originator: "transfer",
                 transfer: %{
                   other_account_id: to_account_id
                 },
                 value: 200
               })

      transactions = Transactions.transactions_in_period(~D[2022-01-01], ~D[2022-04-01])

      assert [
               {~D[2022-01-01], from_account_id, Decimal.new(200)},
               {~D[2022-01-01], to_account_id, Decimal.new(-200)},
               {~D[2022-02-01], from_account_id, Decimal.new(200)},
               {~D[2022-02-01], to_account_id, Decimal.new(-200)},
               {~D[2022-03-01], from_account_id, Decimal.new(200)},
               {~D[2022-03-01], to_account_id, Decimal.new(-200)},
               {~D[2022-04-01], from_account_id, Decimal.new(200)},
               {~D[2022-04-01], to_account_id, Decimal.new(-200)}
             ] ==
               transactions
               |> Enum.map(&{&1.date, &1.account_id, &1.value})

      assert Enum.at(transactions, 0).id |> is_integer()
      assert Enum.at(transactions, 1).id |> is_integer()
      assert "recurrency-" <> _ = Enum.at(transactions, 2).id
      assert "recurrency-" <> _ = Enum.at(transactions, 3).id
      assert "recurrency-" <> _ = Enum.at(transactions, 4).id
      assert "recurrency-" <> _ = Enum.at(transactions, 5).id
      assert "recurrency-" <> _ = Enum.at(transactions, 6).id
      assert "recurrency-" <> _ = Enum.at(transactions, 7).id

      {:ok, _persisted} = Transaction.Form.apply_update(Enum.at(transactions, 2), %{})

      transactions = Transactions.transactions_in_period(~D[2022-01-01], ~D[2022-04-01])

      assert [
               {~D[2022-01-01], from_account_id, Decimal.new(200)},
               {~D[2022-01-01], to_account_id, Decimal.new(-200)},
               {~D[2022-02-01], from_account_id, Decimal.new(200)},
               {~D[2022-02-01], to_account_id, Decimal.new(-200)},
               {~D[2022-03-01], from_account_id, Decimal.new(200)},
               {~D[2022-03-01], to_account_id, Decimal.new(-200)},
               {~D[2022-04-01], from_account_id, Decimal.new(200)},
               {~D[2022-04-01], to_account_id, Decimal.new(-200)}
             ] ==
               transactions
               |> Enum.map(&{&1.date, &1.account_id, &1.value})

      assert 4 == Budget.Repo.all(Transactions.RecurrencyTransaction) |> length()

      assert Enum.at(transactions, 0).id |> is_integer()
      assert Enum.at(transactions, 1).id |> is_integer()
      assert Enum.at(transactions, 2).id |> is_integer()
      assert Enum.at(transactions, 3).id |> is_integer()
      assert "recurrency-" <> _ = Enum.at(transactions, 4).id
      assert "recurrency-" <> _ = Enum.at(transactions, 5).id
      assert "recurrency-" <> _ = Enum.at(transactions, 6).id
      assert "recurrency-" <> _ = Enum.at(transactions, 7).id
    end

    test "persist recurrent transfer transaction applying forward" do
      %{id: from_account_id} = account_fixture()
      %{id: to_account_id} = account_fixture()

      assert {:ok, _} =
               Transaction.Form.apply_insert(%{
                 date: ~D[2022-01-01],
                 account_id: from_account_id,
                 recurrency: %{
                   frequency: :monthly,
                   is_forever: true
                 },
                 originator: "transfer",
                 transfer: %{
                   other_account_id: to_account_id
                 },
                 value: 200
               })

      transactions = Transactions.transactions_in_period(~D[2022-01-01], ~D[2022-04-01])

      assert [
               {~D[2022-01-01], from_account_id, Decimal.new(200), "part"},
               {~D[2022-01-01], to_account_id, Decimal.new(-200), "counter-part"},
               {~D[2022-02-01], from_account_id, Decimal.new(200), "part"},
               {~D[2022-02-01], to_account_id, Decimal.new(-200), "counter-part"},
               {~D[2022-03-01], from_account_id, Decimal.new(200), "part"},
               {~D[2022-03-01], to_account_id, Decimal.new(-200), "counter-part"},
               {~D[2022-04-01], from_account_id, Decimal.new(200), "part"},
               {~D[2022-04-01], to_account_id, Decimal.new(-200), "counter-part"}
             ] ==
               transactions
               |> Enum.map(
                 &{
                   &1.date,
                   &1.account_id,
                   &1.value,
                   if(
                     Ecto.assoc_loaded?(&1.originator_transfer_part) &&
                       &1.originator_transfer_part != nil,
                     do: "part",
                     else: "counter-part"
                   )
                 }
               )

      {:ok, _persisted} =
        Transaction.Form.apply_update(Enum.at(transactions, 2), %{
          value: 400,
          apply_forward: true
        })

      transactions = Transactions.transactions_in_period(~D[2022-01-01], ~D[2022-04-01])

      assert [
               {~D[2022-01-01], from_account_id, Decimal.new(200)},
               {~D[2022-01-01], to_account_id, Decimal.new(-200)},
               {~D[2022-02-01], from_account_id, Decimal.new(400)},
               {~D[2022-02-01], to_account_id, Decimal.new(-400)},
               {~D[2022-03-01], from_account_id, Decimal.new(400)},
               {~D[2022-03-01], to_account_id, Decimal.new(-400)},
               {~D[2022-04-01], from_account_id, Decimal.new(400)},
               {~D[2022-04-01], to_account_id, Decimal.new(-400)}
             ] ==
               transactions
               |> Enum.map(&{&1.date, &1.account_id, &1.value})
    end
  end

  describe "update_transaction/2" do
    test "updating value from a transfer transaction" do
      %{id: from_account_id} = account_fixture()
      %{id: to_account_id} = account_fixture()

      assert {:ok, %{id: id}} =
               Transaction.Form.apply_insert(%{
                 date: ~D[2022-01-01],
                 account_id: from_account_id,
                 originator: "transfer",
                 transfer: %{
                   other_account_id: to_account_id
                 },
                 value: 200
               })

      transaction = Transactions.get_transaction!(id)

      assert {:ok, _} = Transaction.Form.apply_update(transaction, %{value: 400})

      assert [
               {from_account_id, Decimal.new(400), transaction.originator_transfer_part_id, nil},
               {to_account_id, Decimal.new(-400), nil, transaction.originator_transfer_part_id}
             ] ==
               Transactions.transactions_in_period(~D[2022-01-01], ~D[2022-01-01])
               |> Enum.map(
                 &{&1.account_id, &1.value, &1.originator_transfer_part_id,
                  &1.originator_transfer_counter_part_id}
               )
    end
  end

  describe "delete_transaction_state/1" do
    test "transaction_state for an alone transaction" do
      transaction = transaction_fixture()

      assert :regular == Transactions.delete_transaction_state(transaction.id)
    end

    test "transaction_state for a recurrency transaction without future persisted" do
      recurrency = recurrency_fixture()

      transaction = Enum.at(recurrency.recurrency_transactions, 0).transaction

      assert :recurrency == Transactions.delete_transaction_state(transaction.id)
    end

    test "transaction_state for a recurrency transaction with future persisted" do
      recurrency = recurrency_fixture()

      {:ok, _} =
        recurrency
        |> Transactions.recurrency_transactions(Timex.today() |> Timex.shift(months: 1))
        |> Enum.at(0)
        |> Transaction.Form.apply_update(%{})

      transaction = Enum.at(recurrency.recurrency_transactions, 0).transaction

      assert :recurrency_with_future == Transactions.delete_transaction_state(transaction.id)
    end

    test "transaction_state for a recurrency transient transaction with future persisted" do
      recurrency = recurrency_fixture()

      transactions =
        Transactions.recurrency_transactions(recurrency, Timex.today() |> Timex.shift(months: 4))

      {:ok, _} =
        transactions
        |> Enum.at(3)
        |> Transaction.Form.apply_update(%{})

      assert :recurrency_with_future ==
               Transactions.delete_transaction_state(Enum.at(transactions, 1).id)
    end

    test "transaction_state for a recurrency transient transaction with future deleted" do
      recurrency = recurrency_fixture()

      transactions =
        Transactions.recurrency_transactions(recurrency, Timex.today() |> Timex.shift(months: 4))

      {:ok, transaction} =
        transactions
        |> Enum.at(3)
        |> Transaction.Form.apply_update(%{})

      {:ok, _} = Transactions.delete_transaction(transaction.id, "transaction")

      assert :recurrency == Transactions.delete_transaction_state(Enum.at(transactions, 1).id)
    end
  end

  def delete_transaction_payload("regular") do
    account_id = account_fixture().id
    category_id = category_fixture().id

    %{
      date: ~D[2020-01-01],
      originator: "regular",
      account_id: account_id,
      regular: %{
        description: "something",
        category_id: category_id
      },
      value: 200,
      recurrency: %{
        is_forever: true,
        frequency: :monthly
      }
    }
    |> Transaction.Form.apply_insert()
  end

  def delete_transaction_payload(Regular) do
    category_id = category_fixture().id

    %{
      originator: "regular",
      regular: %{
        description: "something",
        category_id: category_id
      }
    }
  end

  def delete_transaction_payload(Transfer) do
    account_id2 = account_fixture().id

    %{
      originator: "transfer",
      transfer: %{
        other_account_id: account_id2
      }
    }
  end

  describe "delete_transaction/2" do
    Enum.each(
      [Regular, Transfer],
      fn originator ->
        test "delete_transaction mode transaction for an alone transaction #{originator}" do
          account_id = account_fixture().id

          {:ok, transaction} =
            unquote(originator)
            |> delete_transaction_payload()
            |> Map.merge(%{
              date: ~D[2020-01-01],
              account_id: account_id,
              value: 200
            })
            |> Transaction.Form.apply_insert()

          assert {:ok, _} = Transactions.delete_transaction(transaction.id, "transaction")

          assert 0 == Budget.Repo.all(Budget.Transactions.Transaction) |> length()
          assert 0 == Budget.Repo.all(unquote(originator)) |> length()
        end

        test "delete_transaction mode transaction for a recurrent #{originator}" do
          account_id = account_fixture().id

          {:ok, transaction} =
            unquote(originator)
            |> delete_transaction_payload()
            |> Map.merge(%{
              date: ~D[2020-01-01],
              account_id: account_id,
              value: 200,
              recurrency: %{
                frequency: :monthly,
                is_forever: true
              }
            })
            |> Transaction.Form.apply_insert()

          assert {:ok, _} = Transactions.delete_transaction(transaction.id, "transaction")

          assert 0 == Budget.Repo.all(Budget.Transactions.Transaction) |> length()
          assert 0 == Budget.Repo.all(unquote(originator)) |> length()
        end

        test "delete_transaction mode recurrency-keep-future for a recurrency transaction #{originator}" do
          account_id = account_fixture().id

          {:ok, transaction} =
            unquote(originator)
            |> delete_transaction_payload()
            |> Map.merge(%{
              date: ~D[2020-01-01],
              account_id: account_id,
              value: 200,
              recurrency: %{
                frequency: :monthly,
                is_forever: true
              }
            })
            |> Transaction.Form.apply_insert()

          recurrency =
            Transactions.get_recurrency!(transaction.recurrency_transaction.recurrency.id)

          [transient | _] =
            Transactions.recurrency_transactions(recurrency, ~D[2020-02-01])

          {:ok, _} = Transaction.Form.apply_update(transient, %{})

          assert {:ok, _} =
                   Transactions.delete_transaction(transaction.id, "recurrency-keep-future")

          assert Transactions.get_recurrency!(recurrency.id).date_end ==
                   ~D[2019-12-31]

          assert Budget.Repo.all(Budget.Transactions.Transaction) |> length() > 0
          assert Budget.Repo.all(unquote(originator)) |> length() > 0
        end

        test "delete_transaction mode recurrency-all for a recurrency transaction #{originator}" do
          account_id = account_fixture().id

          {:ok, transaction} =
            unquote(originator)
            |> delete_transaction_payload()
            |> Map.merge(%{
              date: ~D[2020-01-01],
              account_id: account_id,
              value: 200,
              recurrency: %{
                frequency: :monthly,
                is_forever: true
              }
            })
            |> Transaction.Form.apply_insert()

          recurrency =
            Transactions.get_recurrency!(transaction.recurrency_transaction.recurrency.id)

          [transient | _] =
            Transactions.recurrency_transactions(recurrency, ~D[2020-02-01])

          {:ok, _} = Transaction.Form.apply_update(transient, %{})

          assert {:ok, _} = Transactions.delete_transaction(transaction.id, "recurrency-all")

          assert Transactions.get_recurrency!(recurrency.id).date_end ==
                   ~D[2019-12-31]

          assert Budget.Repo.all(Budget.Transactions.Transaction) |> length() == 0
          assert Budget.Repo.all(unquote(originator)) |> length() == 0
        end

        test "delete_transaction mode transaction for a transient recurrency transaction #{originator}" do
          account_id = account_fixture().id

          {:ok, transaction} =
            unquote(originator)
            |> delete_transaction_payload()
            |> Map.merge(%{
              date: ~D[2020-01-01],
              account_id: account_id,
              value: 200,
              recurrency: %{
                frequency: :monthly,
                is_forever: true
              }
            })
            |> Transaction.Form.apply_insert()

          recurrency =
            Transactions.get_recurrency!(transaction.recurrency_transaction.recurrency.id)

          [transient | _] = Transactions.recurrency_transactions(recurrency, ~D[2020-02-01])

          assert {:ok, _} = Transactions.delete_transaction(transient.id, "transaction")

          recurrency =
            Transactions.get_recurrency!(transaction.recurrency_transaction.recurrency.id)

          assert [] == Transactions.recurrency_transactions(recurrency, ~D[2020-02-01])
        end

        test "delete_transaction mode recurrency-keep-future for a transient recurrency transaction #{originator}" do
          account_id = account_fixture().id

          {:ok, transaction} =
            unquote(originator)
            |> delete_transaction_payload()
            |> Map.merge(%{
              date: ~D[2020-01-01],
              account_id: account_id,
              value: 200,
              recurrency: %{
                frequency: :monthly,
                is_forever: true
              }
            })
            |> Transaction.Form.apply_insert()

          recurrency =
            Transactions.get_recurrency!(transaction.recurrency_transaction.recurrency.id)

          [transient | _] = Transactions.transactions_in_period(~D[2020-02-01], ~D[2020-02-01])

          [future | _] = Transactions.transactions_in_period(~D[2020-03-01], ~D[2020-03-01])

          {:ok, persisted} = Transaction.Form.apply_update(future, %{})

          assert {:ok, _} =
                   Transactions.delete_transaction(transient.id, "recurrency-keep-future")

          recurrency = Transactions.get_recurrency!(recurrency.id)

          assert recurrency.date_end == ~D[2020-01-31]

          assert Transactions.get_transaction!(persisted.id)

          assert [
                   %{has_transaction_id: true, original_date: ~D[2020-01-01]},
                   %{has_transaction_id: false, original_date: ~D[2020-02-01]},
                   %{has_transaction_id: true, original_date: ~D[2020-03-01]}
                 ] ==
                   Enum.map(
                     recurrency.recurrency_transactions,
                     &%{
                       has_transaction_id: not is_nil(&1.transaction_id),
                       original_date: &1.original_date
                     }
                   )
                   |> Enum.sort_by(& &1.original_date, &Timex.before?/2)
                   |> Enum.uniq()
        end

        test "delete_transaction mode recurrency-all when there is already a deleted transaction in the future #{originator}" do
          account_id = account_fixture().id

          {:ok, transaction} =
            unquote(originator)
            |> delete_transaction_payload()
            |> Map.merge(%{
              date: ~D[2020-01-01],
              account_id: account_id,
              value: 200,
              recurrency: %{
                frequency: :monthly,
                is_forever: true
              }
            })
            |> Transaction.Form.apply_insert()

          [transient | _] = Transactions.transactions_in_period(~D[2020-02-01], ~D[2020-02-01])
          [future | _] = Transactions.transactions_in_period(~D[2020-03-01], ~D[2020-03-01])

          {:ok, persisted} = Transaction.Form.apply_update(future, %{})

          assert {:ok, _} = Transactions.delete_transaction(persisted.id, "transaction")

          assert {:ok, _} = Transactions.delete_transaction(transient.id, "recurrency-all")

          recurrency =
            Transactions.get_recurrency!(transaction.recurrency_transaction.recurrency.id)

          assert recurrency.date_end == ~D[2020-01-31]

          assert [
                   %{has_transaction_id: true, original_date: ~D[2020-01-01]},
                   %{has_transaction_id: false, original_date: ~D[2020-02-01]},
                   %{has_transaction_id: false, original_date: ~D[2020-03-01]}
                 ] ==
                   Enum.map(
                     recurrency.recurrency_transactions,
                     &%{
                       has_transaction_id: not is_nil(&1.transaction_id),
                       original_date: &1.original_date
                     }
                   )
                   |> Enum.sort_by(& &1.original_date, &Timex.before?/2)
                   |> Enum.uniq()
        end
      end
    )
  end

  describe "create_category/2" do
    test "create root category" do
      assert {:ok, %Category{name: "root"}} = Transactions.create_category(%{name: "root"})
    end

    test "create child category" do
      {:ok, %{id: id} = parent} = Transactions.create_category(%{name: "root"})

      assert {:ok, %{name: "child", path: [^id]}} =
               Transactions.create_category(%{name: "child"}, parent)
    end
  end

  describe "list_categories_arranged/0" do
    @tag :skip
    test "list all categoris" do
      {:ok, %{id: id_root} = root} = Transactions.create_category(%{name: "root"})
      {:ok, %{id: id_parent} = parent} = Transactions.create_category(%{name: "parent"}, root)

      assert {:ok, %{name: "child", path: [^id_root, ^id_parent]}} =
               Transactions.create_category(%{name: "child"}, parent)

      assert [
               %{name: "root"} = root,
               %{name: "parent"} = parent,
               %{name: "child"} = child
             ] =
               root
               |> Category.subtree()
               |> Budget.Repo.all()
               |> Enum.map(&Map.put(&1, :transactions_count, 0))

      assert [
               {^root,
                [
                  {^parent,
                   [
                     {^child, []}
                   ]}
                ]}
             ] = Transactions.list_categories_arranged()
    end
  end

  describe "put_transaction_before/2" do
    test "reorder between 3 elements" do
      transaction_1 = %{id: id1} = transaction_fixture()
      transaction_2 = %{id: id2} = transaction_fixture()
      transaction_3 = %{id: id3} = transaction_fixture()

      assert Decimal.new(1) == transaction_1.position
      assert Decimal.new(2) == transaction_2.position
      assert Decimal.new(3) == transaction_3.position

      {:ok, updated} =
        Transactions.put_transaction_between(transaction_3, [transaction_1, transaction_2])

      assert Decimal.new("1.5") == updated.position

      transactions = Transactions.transactions_in_period(Timex.today(), Timex.today())

      assert [
               {id1, Decimal.new(1)},
               {id3, Decimal.new("1.5")},
               {id2, Decimal.new(2)}
             ] ==
               transactions |> Enum.map(&{&1.id, &1.position})

      [transaction_1, transaction_3, transaction_2] = transactions

      {:ok, _} =
        Transactions.put_transaction_between(transaction_1, [transaction_3, transaction_2])

      assert Decimal.new("1.5") == updated.position

      transactions = Transactions.transactions_in_period(Timex.today(), Timex.today())

      assert [
               {id3, Decimal.new("1.5")},
               {id1, Decimal.new("1.75")},
               {id2, Decimal.new(2)}
             ] ==
               transactions |> Enum.map(&{&1.id, &1.position})
    end

    test "reorder between 2 elements and it is put after the other" do
      transaction_1 = %{id: id1} = transaction_fixture(%{date: ~D[2023-01-17]})
      transaction_2 = %{id: id2} = transaction_fixture(%{date: ~D[2023-01-21]})

      {:ok, _} = Transactions.put_transaction_between(transaction_1, [transaction_2, nil])

      transactions = Transactions.transactions_in_period(~D[2023-01-17], ~D[2023-01-21])

      assert [
               {id2, Decimal.new(1), ~D[2023-01-21]},
               {id1, Decimal.new("1.5"), ~D[2023-01-21]}
             ] ==
               transactions |> Enum.map(&{&1.id, &1.position, &1.date})
    end

    test "reorder between 2 elements and it is put before the other" do
      transaction_1 = %{id: id1} = transaction_fixture(%{date: ~D[2023-01-17]})
      transaction_2 = %{id: id2} = transaction_fixture(%{date: ~D[2023-01-21]})

      {:ok, _} = Transactions.put_transaction_between(transaction_2, [nil, transaction_1])

      transactions = Transactions.transactions_in_period(~D[2023-01-17], ~D[2023-01-21])

      assert [
               {id2, Decimal.new("0.5"), ~D[2023-01-17]},
               {id1, Decimal.new(1), ~D[2023-01-17]}
             ] ==
               transactions |> Enum.map(&{&1.id, &1.position, &1.date})
    end

    test "reorder between 3 elements putting last in first updating date" do
      transaction_1 = %{id: id1} = transaction_fixture(%{date: ~D[2023-01-17]})
      _transaction_2 = %{id: id2} = transaction_fixture(%{date: ~D[2023-01-18]})
      transaction_3 = %{id: id3} = transaction_fixture(%{date: ~D[2023-01-19]})

      {:ok, _} = Transactions.put_transaction_between(transaction_3, [nil, transaction_1])

      transactions = Transactions.transactions_in_period(~D[2023-01-17], ~D[2023-01-19])

      assert [
               {id3, Decimal.new("0.5"), ~D[2023-01-17]},
               {id1, Decimal.new(1), ~D[2023-01-17]},
               {id2, Decimal.new(1), ~D[2023-01-18]}
             ] ==
               transactions |> Enum.map(&{&1.id, &1.position, &1.date})
    end

    test "reorder between 3 elements putting last in middle updating date" do
      transaction_1 = %{id: id1} = transaction_fixture(%{date: ~D[2023-01-17]})
      transaction_2 = %{id: id2} = transaction_fixture(%{date: ~D[2023-01-18]})
      transaction_3 = %{id: id3} = transaction_fixture(%{date: ~D[2023-01-19]})

      {:ok, _} =
        Transactions.put_transaction_between(transaction_3, [transaction_1, transaction_2])

      transactions = Transactions.transactions_in_period(~D[2023-01-17], ~D[2023-01-19])

      assert [
               {id1, Decimal.new(1), ~D[2023-01-17]},
               {id3, Decimal.new("1.5"), ~D[2023-01-17]},
               {id2, Decimal.new(1), ~D[2023-01-18]}
             ] ==
               transactions |> Enum.map(&{&1.id, &1.position, &1.date})
    end

    test "reorder between 3 elements putting first in middle updating date" do
      transaction_1 = %{id: id1} = transaction_fixture(%{date: ~D[2023-01-17]})
      transaction_2 = %{id: id2} = transaction_fixture(%{date: ~D[2023-01-18]})
      transaction_3 = %{id: id3} = transaction_fixture(%{date: ~D[2023-01-19]})

      {:ok, _} =
        Transactions.put_transaction_between(transaction_1, [transaction_2, transaction_3])

      transactions = Transactions.transactions_in_period(~D[2023-01-17], ~D[2023-01-19])

      assert [
               {id2, Decimal.new(1), ~D[2023-01-18]},
               {id1, Decimal.new("1.5"), ~D[2023-01-18]},
               {id3, Decimal.new(1), ~D[2023-01-19]}
             ] ==
               transactions |> Enum.map(&{&1.id, &1.position, &1.date})
    end

    test "reorder between 3 elements putting first in last updating date" do
      transaction_1 = %{id: id1} = transaction_fixture(%{date: ~D[2023-01-17]})
      _transaction_2 = %{id: id2} = transaction_fixture(%{date: ~D[2023-01-18]})
      transaction_3 = %{id: id3} = transaction_fixture(%{date: ~D[2023-01-19]})

      {:ok, _} = Transactions.put_transaction_between(transaction_1, [transaction_3, nil])

      transactions = Transactions.transactions_in_period(~D[2023-01-17], ~D[2023-01-19])

      assert [
               {id2, Decimal.new(1), ~D[2023-01-18]},
               {id3, Decimal.new(1), ~D[2023-01-19]},
               {id1, Decimal.new("1.5"), ~D[2023-01-19]}
             ] ==
               transactions |> Enum.map(&{&1.id, &1.position, &1.date})
    end

    test "reorder with different dates and various positions" do
      transaction_1 = %{id: id1} = transaction_fixture(%{date: ~D[2023-01-01], position: "4.5"})
      _transaction_2 = %{id: id2} = transaction_fixture(%{date: ~D[2023-01-01], position: "4.75"})
      transaction_3 = %{id: id3} = transaction_fixture(%{date: ~D[2023-01-13], position: "2"})
      transaction_4 = %{id: id4} = transaction_fixture(%{date: ~D[2023-01-28], position: "1"})
      _transaction_5 = %{id: id5} = transaction_fixture(%{date: ~D[2023-01-28], position: "5"})

      {:ok, _} =
        Transactions.put_transaction_between(transaction_1, [transaction_3, transaction_4])

      transactions = Transactions.transactions_in_period(~D[2023-01-01], ~D[2023-01-31])

      assert [
               {id2, Decimal.new("4.75"), ~D[2023-01-01]},
               {id3, Decimal.new(2), ~D[2023-01-13]},
               {id1, Decimal.new("2.5"), ~D[2023-01-13]},
               {id4, Decimal.new("1"), ~D[2023-01-28]},
               {id5, Decimal.new("5"), ~D[2023-01-28]}
             ] ==
               transactions |> Enum.map(&{&1.id, &1.position, &1.date})
    end
  end

  describe "update_order/3" do
    test "basic reorder" do
      transaction_1 = %{id: id1} = transaction_fixture()
      transaction_2 = %{id: id2} = transaction_fixture()
      transaction_3 = %{id: id3} = transaction_fixture()
      transaction_4 = %{id: id4} = transaction_fixture()
      transaction_5 = %{id: id5} = transaction_fixture()

      {:ok, _} =
        Transactions.update_order(0, 2, [
          transaction_1,
          transaction_2,
          transaction_3,
          transaction_4,
          transaction_5
        ])

      transactions = Transactions.transactions_in_period(Timex.today(), Timex.today())

      assert [id2, id3, id1, id4, id5] == transactions |> Enum.map(& &1.id)
    end
  end
end

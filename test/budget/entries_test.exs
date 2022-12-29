defmodule Budget.EntriesTest do
  use Budget.DataCase, async: true

  alias Budget.Entries
  alias Budget.Entries.Recurrency
  alias Budget.Entries.Entry
  alias Budget.Entries.Category

  import Budget.EntriesFixtures

  def create_account(_) do
    {:ok, account1} =
      Entries.create_account(%{
        name: "Account name",
        initial_balance: -10
      })

    {:ok, account2} =
      Entries.create_account(%{
        name: "Account name",
        initial_balance: 50
      })

    %{account1: account1, account2: account2}
  end

  describe "change_recurrency/2" do
    setup :create_account

    test "finite recurrency", %{account1: account} do
      changeset =
        Entries.change_recurrency(%Recurrency{}, %{
          date_start: "2022-10-01",
          date_end: "2022-10-01",
          account_id: account.id,
          is_forever: false,
          is_parcel: false,
          frequency: :monthly,
          entry_payload: %{
            originator_regular: %{
              description: "Some description",
              category_id: category_fixture().id
            },
            value: 200
          }
        })

      assert %{valid?: true} = changeset

      changeset =
        Entries.change_recurrency(%Recurrency{}, %{
          date_start: "2022-10-01",
          account_id: account.id,
          is_forever: false,
          is_parcel: false,
          frequency: :monthly,
          entry_payload: %{
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
        Entries.change_recurrency(%Recurrency{}, %{
          date_start: "2022-10-01",
          date_end: "2022-10-01",
          value: "200",
          account_id: account.id,
          is_forever: true,
          is_parcel: false,
          frequency: :monthly,
          entry_payload: %{
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
        Entries.change_recurrency(%Recurrency{}, %{
          date_start: "2022-10-01",
          date_end: "2022-10-01",
          account_id: account.id,
          is_forever: true,
          is_parcel: true,
          frequency: :monthly,
          entry_payload: %{
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
        Entries.change_recurrency(%Recurrency{}, %{
          date_start: "2022-10-01",
          is_forever: false,
          is_parcel: true,
          frequency: :monthly,
          account_id: account.id,
          entry_payload: %{
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

    test "calculate finite recurrency entries until date - monthly" do
      recurrency =
        recurrency_fixture(%{
          originator_regular: %{
            description: "Some description",
            category_id: category_fixture().id
          },
          value: 200,
          recurrency_entry: %{
            recurrency: %{
              is_forever: false,
              frequency: :monthly,
              date_start: ~D[2019-01-01],
              date_end: ~D[2019-03-31]
            }
          }
        })

      assert [
               %{date: ~D[2019-01-01], value: 200, description: "Some description"},
               %{date: ~D[2019-02-01], value: 200, description: "Some description"},
               %{date: ~D[2019-03-01], value: 200, description: "Some description"}
             ] =
               Entries.recurrency_entries(recurrency, ~D[2019-03-15])
               |> Enum.map(
                 &%{
                   date: &1.date,
                   value: Decimal.to_integer(&1.value),
                   description: &1.originator_regular.description
                 }
               )

      assert [
               %{date: ~D[2019-01-01], value: 200, description: "Some description"},
               %{date: ~D[2019-02-01], value: 200, description: "Some description"},
               %{date: ~D[2019-03-01], value: 200, description: "Some description"}
             ] =
               Entries.recurrency_entries(recurrency, ~D[2019-03-01])
               |> Enum.map(
                 &%{
                   date: &1.date,
                   value: Decimal.to_integer(&1.value),
                   description: &1.originator_regular.description
                 }
               )

      assert [] = Entries.recurrency_entries(recurrency, ~D[2018-03-01])

      assert [
               %{date: ~D[2019-01-01], value: 200, description: "Some description"},
               %{date: ~D[2019-02-01], value: 200, description: "Some description"},
               %{date: ~D[2019-03-01], value: 200, description: "Some description"}
             ] =
               Entries.recurrency_entries(recurrency, ~D[2019-06-01])
               |> Enum.map(
                 &%{
                   date: &1.date,
                   value: Decimal.to_integer(&1.value),
                   description: &1.originator_regular.description
                 }
               )
    end

    test "calculate finite recurrency entries until date - weekly" do
      recurrency =
        recurrency_fixture(%{
          originator_regular: %{
            description: "Some description",
            category_id: category_fixture().id
          },
          value: 200,
          recurrency_entry: %{
            recurrency: %{
              is_forever: false,
              frequency: :weekly,
              value: 200,
              date_start: ~D[2019-01-01],
              date_end: ~D[2019-01-31]
            }
          }
        })

      assert [
               %{date: ~D[2019-01-01], value: 200, description: "Some description"},
               %{date: ~D[2019-01-08], value: 200, description: "Some description"},
               %{date: ~D[2019-01-15], value: 200, description: "Some description"},
               %{date: ~D[2019-01-22], value: 200, description: "Some description"},
               %{date: ~D[2019-01-29], value: 200, description: "Some description"}
             ] =
               Entries.recurrency_entries(recurrency, ~D[2019-03-15])
               |> Enum.map(
                 &%{
                   date: &1.date,
                   value: Decimal.to_integer(&1.value),
                   description: &1.originator_regular.description
                 }
               )

      assert [
               %{date: ~D[2019-01-01], value: 200, description: "Some description"},
               %{date: ~D[2019-01-08], value: 200, description: "Some description"},
               %{date: ~D[2019-01-15], value: 200, description: "Some description"}
             ] =
               Entries.recurrency_entries(recurrency, ~D[2019-01-15])
               |> Enum.map(
                 &%{
                   date: &1.date,
                   value: Decimal.to_integer(&1.value),
                   description: &1.originator_regular.description
                 }
               )

      assert [] = Entries.recurrency_entries(recurrency, ~D[2018-03-01])

      assert [
               %{date: ~D[2019-01-01], value: 200, description: "Some description"},
               %{date: ~D[2019-01-08], value: 200, description: "Some description"},
               %{date: ~D[2019-01-15], value: 200, description: "Some description"},
               %{date: ~D[2019-01-22], value: 200, description: "Some description"},
               %{date: ~D[2019-01-29], value: 200, description: "Some description"}
             ] =
               Entries.recurrency_entries(recurrency, ~D[2019-06-01])
               |> Enum.map(
                 &%{
                   date: &1.date,
                   value: Decimal.to_integer(&1.value),
                   description: &1.originator_regular.description
                 }
               )
    end

    test "calculate infinite recurrency entries starting date 31" do
      recurrency =
        recurrency_fixture(%{
          recurrency_entry: %{
            recurrency: %{
              is_forever: false,
              frequency: :monthly,
              date_start: ~D[2019-01-31],
              date_end: ~D[2020-01-31]
            }
          }
        })

      assert [
               ~D[2019-01-31],
               ~D[2019-02-28],
               ~D[2019-03-31],
               ~D[2019-04-30],
               ~D[2019-05-31],
               ~D[2019-06-30],
               ~D[2019-07-31]
             ] ==
               recurrency
               |> Entries.recurrency_entries(~D[2019-07-31])
               |> Enum.map(& &1.date)
    end

    test "calculate parcel weekly 1 to 6" do
      recurrency =
        recurrency_fixture(%{
          originator_regular: %{
            description: "Some description",
            category_id: category_fixture().id
          },
          value: 200,
          recurrency_entry: %{
            recurrency: %{
              is_forever: false,
              is_parcel: true,
              frequency: :weekly,
              date_start: ~D[2019-01-01],
              parcel_start: 1,
              parcel_end: 6
            }
          }
        })

      assert [
               %{date: ~D[2019-01-01], value: 200, description: "Some description", parcel: 1, parcel_end: 6},
               %{date: ~D[2019-01-08], value: 200, description: "Some description", parcel: 2, parcel_end: 6},
               %{date: ~D[2019-01-15], value: 200, description: "Some description", parcel: 3, parcel_end: 6},
               %{date: ~D[2019-01-22], value: 200, description: "Some description", parcel: 4, parcel_end: 6},
               %{date: ~D[2019-01-29], value: 200, description: "Some description", parcel: 5, parcel_end: 6},
               %{date: ~D[2019-02-05], value: 200, description: "Some description", parcel: 6, parcel_end: 6}
             ] =
               Entries.recurrency_entries(recurrency, ~D[2019-04-01])
               |> Enum.map(
                 &%{
                   date: &1.date,
                   value: Decimal.to_integer(&1.value),
                   description: &1.originator_regular.description,
                   parcel: &1.recurrency_entry.parcel,
                   parcel_end: &1.recurrency_entry.parcel_end
                 }
               )

      assert [
               %{date: ~D[2019-01-01], value: 200, description: "Some description", parcel: 1, parcel_end: 6},
               %{date: ~D[2019-01-08], value: 200, description: "Some description", parcel: 2, parcel_end: 6},
               %{date: ~D[2019-01-15], value: 200, description: "Some description", parcel: 3, parcel_end: 6},
               %{date: ~D[2019-01-22], value: 200, description: "Some description", parcel: 4, parcel_end: 6}
             ] =
               Entries.recurrency_entries(recurrency, ~D[2019-01-22])
               |> Enum.map(
                 &%{
                   date: &1.date,
                   value: Decimal.to_integer(&1.value),
                   description: &1.originator_regular.description,
                   parcel: &1.recurrency_entry.parcel,
                   parcel_end: &1.recurrency_entry.parcel_end
                 }
               )
    end

    test "calculate parcel weekly 3 to 6" do
      recurrency =
        recurrency_fixture(%{
          originator_regular: %{
            description: "Some description",
            category_id: category_fixture().id
          },
          value: 200,
          recurrency_entry: %{
            recurrency: %{
              is_forever: false,
              is_parcel: true,
              frequency: :weekly,
              date_start: ~D[2019-01-01],
              parcel_start: 3,
              parcel_end: 6
            }
          }
        })

      assert [
               %{date: ~D[2019-01-01], value: 200, parcel: 3, parcel_end: 6},
               %{date: ~D[2019-01-08], value: 200, parcel: 4, parcel_end: 6},
               %{date: ~D[2019-01-15], value: 200, parcel: 5, parcel_end: 6},
               %{date: ~D[2019-01-22], value: 200, parcel: 6, parcel_end: 6}
             ] =
               Entries.recurrency_entries(recurrency, ~D[2019-04-01])
               |> Enum.map(
                 &%{
                   date: &1.date,
                   value: Decimal.to_integer(&1.value),
                   parcel: &1.recurrency_entry.parcel,
                   parcel_end: &1.recurrency_entry.parcel_end
                 }
               )

      assert [
               %{date: ~D[2019-01-01], value: 200, parcel: 3, parcel_end: 6},
               %{date: ~D[2019-01-08], value: 200, parcel: 4, parcel_end: 6},
               %{date: ~D[2019-01-15], value: 200, parcel: 5, parcel_end: 6}
             ] =
               Entries.recurrency_entries(recurrency, ~D[2019-01-15])
               |> Enum.map(
                 &%{
                   date: &1.date,
                   value: Decimal.to_integer(&1.value),
                   parcel: &1.recurrency_entry.parcel,
                   parcel_end: &1.recurrency_entry.parcel_end
                 }
               )
    end

    test "recurrency when it ends and the end of an entry" do
      recurrency =
        recurrency_fixture(%{
          recurrency_entry: %{
            recurrency: %{
              is_forever: false,
              description: "Some description",
              frequency: :monthly,
              value: 200,
              date_start: ~D[2019-01-01],
              date_end: ~D[2019-03-01]
            }
          }
        })

      assert [
               %{date: ~D[2019-01-01]},
               %{date: ~D[2019-02-01]},
               %{date: ~D[2019-03-01]}
             ] = Entries.recurrency_entries(recurrency, ~D[2019-03-03])
    end
  end

  describe "entries_in_period/3" do
    setup :create_account

    test "retrieve regular entries", %{account1: account} do
      category = category_fixture()

      {:ok, _} =
        Entries.create_entry(%{
          date: ~D[2020-02-01],
          originator_regular: %{
            description: "Description1",
            category_id: category.id
          },
          account_id: account.id,
          value: 200
        })

      {:ok, _} =
        Entries.create_entry(%{
          date: ~D[2020-01-31],
          originator_regular: %{
            description: "Description2",
            category_id: category.id
          },
          account_id: account.id,
          value: 200
        })

      {:ok, _} =
        Entries.create_entry(%{
          date: ~D[2020-02-10],
          originator_regular: %{
            description: "Description3",
            category_id: category.id
          },
          account_id: account.id,
          value: 200
        })

      {:ok, _} =
        Entries.create_entry(%{
          date: ~D[2020-02-11],
          originator_regular: %{
            description: "Description4",
            category_id: category.id
          },
          account_id: account.id,
          value: 200
        })

      entries = Entries.entries_in_period([account.id], ~D[2020-02-01], ~D[2020-02-10])

      assert length(entries) == 2

      entries = Entries.entries_in_period([], ~D[2020-02-01], ~D[2020-02-10])

      assert length(entries) == 2
    end

    test "retrieve recurrency entries", %{account1: account} do
      category = category_fixture()

      {:ok, _entry} =
        Entries.create_entry(%{
          date: ~D[2020-02-01],
          account_id: account.id,
          is_recurrency: true,
          originator_regular: %{
            description: "Description1",
            category_id: category.id
          },
          value: 200,
          recurrency_entry: %{
            original_date: ~D[2020-02-01],
            recurrency: %{
              date_start: ~D[2020-02-01],
              date_end: ~D[2021-02-01],
              frequency: :monthly,
              is_forever: false,
              account_id: account.id
            }
          }
        })

      entries = Entries.entries_in_period([], ~D[2020-01-01], ~D[2020-04-10])

      value = Decimal.new(200)

      assert [
               %Entry{
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
             ] = entries
    end
  end

  describe "balance_at/2" do
    setup :create_account

    test "balance with only initial balance", %{account1: account1, account2: account2} do
      balance = Entries.balance_at([account1.id, account2.id], ~D[2020-01-01])

      assert balance == Decimal.new(40)
    end

    test "balance with entries", %{account1: account1, account2: account2} do
      {:ok, _} =
        Entries.create_entry(%{
          date: ~D[2020-01-05],
          originator_regular: %{
            description: "Description",
            category_id: category_fixture().id
          },
          account_id: account1.id,
          value: 200
        })

      assert Entries.balance_at([account1.id, account2.id], ~D[2020-01-04]) == Decimal.new(40)
      assert Entries.balance_at([account1.id, account2.id], ~D[2020-01-05]) == Decimal.new(240)
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
        recurrency_entry: %{
          recurrency: %{
            date_start: ~D[2020-02-01],
            date_end: ~D[2021-02-01],
            frequency: :monthly,
            is_forever: false,
            value: 200,
            entry_payload: %{
              value: 200,
              originator_regular: %{
                description: "something",
                category_id: category.id
              }
            }
          }
        }
      })

      balance = Entries.balance_at([], ~D[2020-06-01])

      assert balance == Decimal.new(1040)
    end
  end

  describe "create_transient_entry/2" do
    test "create entry and recurrency_entry" do
      recurrency = recurrency_fixture()

      transient_entries =
        Entries.recurrency_entries(
          recurrency,
          Timex.today() |> Timex.shift(months: 3)
        )

      assert length(transient_entries) == 3

      {:ok, created} = Entries.create_entry(Enum.at(transient_entries, 1), %{})

      assert created.recurrency_entry.original_date == Timex.today() |> Timex.shift(months: 2)

      transient_entries =
        recurrency.id
        |> Entries.get_recurrency!()
        |> Entries.recurrency_entries(Timex.today() |> Timex.shift(months: 3))

      assert length(transient_entries) == 2
    end

    test "updating a transient entry applying changes forward" do
      recurrency = recurrency_fixture(%{date: ~D[2022-10-15]})

      [_, transient | _] = Entries.recurrency_entries(recurrency, ~D[2022-12-15])

      assert "recurrency" <> _ = transient.id
      assert transient.date == ~D[2022-12-15]
      assert transient.value == Decimal.new(133)
      assert transient.originator_regular.category_id > 0

      {:ok, _} =
        Entries.create_entry(transient, %{value: 500, recurrency_apply_forward: true})

      entries =
        recurrency.account_id
        |> List.wrap()
        |> Entries.entries_in_period(~D[2022-10-15], ~D[2023-10-15])

      assert %{date: ~D[2022-10-15], value: Decimal.new(133)} ==
               Enum.at(entries, 0) |> Map.take([:date, :value])

      assert %{date: ~D[2022-11-15], value: Decimal.new(133)} ==
               Enum.at(entries, 1) |> Map.take([:date, :value])

      assert %{date: ~D[2022-12-15], value: Decimal.new(500)} ==
               Enum.at(entries, 2) |> Map.take([:date, :value])

      assert %{date: ~D[2023-01-15], value: Decimal.new(500)} ==
               Enum.at(entries, 3) |> Map.take([:date, :value])

      assert %{date: ~D[2023-02-15], value: Decimal.new(500)} ==
               Enum.at(entries, 4) |> Map.take([:date, :value])

      assert %{date: ~D[2023-03-15], value: Decimal.new(500)} ==
               Enum.at(entries, 5) |> Map.take([:date, :value])

      assert %{date: ~D[2023-04-15], value: Decimal.new(500)} ==
               Enum.at(entries, 6) |> Map.take([:date, :value])
    end

    test "updating a transient entry from parcel applying changes forward" do
      recurrency =
        recurrency_fixture(%{
          date: ~D[2022-10-15],
          recurrency_entry: %{
            recurrency: %{
              date_start: ~D[2022-10-15],
              is_forever: false,
              is_parcel: true,
              parcel_start: 1,
              parcel_end: 6
            }
          }
        })

      [_, transient | _] = Entries.recurrency_entries(recurrency, ~D[2022-12-15])

      assert "recurrency" <> _ = transient.id
      assert transient.date == ~D[2022-12-15]
      assert transient.value == Decimal.new(133)
      assert transient.originator_regular.description == "Entry description"
      assert transient.recurrency_entry.parcel == 3
      assert transient.recurrency_entry.parcel_end == 6

      {:ok, _} =
        Entries.create_entry(transient, %{value: 500, recurrency_apply_forward: true})

      entries =
        recurrency.account_id
        |> List.wrap()
        |> Entries.entries_in_period(~D[2022-10-15], ~D[2023-10-15])

      assert %{
               date: ~D[2022-10-15],
               value: Decimal.new(133),
               description: "Entry description",
               parcel: 1
             } ==
               Enum.at(entries, 0)
               |> then(
                 &%{
                   date: &1.date,
                   value: &1.value,
                   description: &1.originator_regular.description,
                   parcel: &1.recurrency_entry.parcel
                 }
               )

      assert %{
               date: ~D[2022-11-15],
               value: Decimal.new(133),
               description: "Entry description",
               parcel: 2
             } ==
               Enum.at(entries, 1)
               |> then(
                 &%{
                   date: &1.date,
                   value: &1.value,
                   description: &1.originator_regular.description,
                   parcel: &1.recurrency_entry.parcel
                 }
               )

      assert %{
               date: ~D[2022-12-15],
               value: Decimal.new(500),
               description: "Entry description",
               parcel: 3
             } ==
               Enum.at(entries, 2)
               |> then(
                 &%{
                   date: &1.date,
                   value: &1.value,
                   description: &1.originator_regular.description,
                   parcel: &1.recurrency_entry.parcel
                 }
               )

      assert %{
               date: ~D[2023-01-15],
               value: Decimal.new(500),
               description: "Entry description",
               parcel: 4
             } ==
               Enum.at(entries, 3)
               |> then(
                 &%{
                   date: &1.date,
                   value: &1.value,
                   description: &1.originator_regular.description,
                   parcel: &1.recurrency_entry.parcel
                 }
               )

      assert %{
               date: ~D[2023-02-15],
               value: Decimal.new(500),
               description: "Entry description",
               parcel: 5
             } ==
               Enum.at(entries, 4)
               |> then(
                 &%{
                   date: &1.date,
                   value: &1.value,
                   description: &1.originator_regular.description,
                   parcel: &1.recurrency_entry.parcel
                 }
               )

      assert %{
               date: ~D[2023-03-15],
               value: Decimal.new(500),
               description: "Entry description",
               parcel: 6
             } ==
               Enum.at(entries, 5)
               |> then(
                 &%{
                   date: &1.date,
                   value: &1.value,
                   description: &1.originator_regular.description,
                   parcel: &1.recurrency_entry.parcel
                 }
               )

      assert nil == Enum.at(entries, 6)
    end

    test "updating recurrency entry without applying changes forward" do
      recurrency =
        recurrency_fixture(%{
          date: ~D[2022-10-15],
          recurrency_entry: %{
            recurrency: %{
              date_start: ~D[2022-10-15],
              is_forever: false,
              is_parcel: true,
              parcel_start: 1,
              parcel_end: 6
            }
          }
        })

      [_, transient | _] = Entries.recurrency_entries(recurrency, ~D[2022-12-15])

      transient_date = ~D[2022-12-15]

      assert "recurrency" <> _ = transient.id
      assert transient_date == transient.date

      assert %{
               "2022-10-15" => %{
                 "originator_regular" => %{
                   "category_id" => _,
                   "description" => "Entry description"
                 },
                 "value" => "133"
               }
             } = recurrency.entry_payload

      {:ok, _} =
        Entries.create_entry(transient, %{value: 500, recurrency_apply_forward: false})


      assert %{
               "2022-10-15" => %{
                 "originator_regular" => %{
                   "category_id" => _,
                   "description" => "Entry description"
                 },
                 "value" => "133"
               }
             } = Entries.get_recurrency!(recurrency.id).entry_payload

      entries =
        recurrency.account_id
        |> List.wrap()
        |> Entries.entries_in_period(~D[2022-10-15], ~D[2023-10-15])

      assert Decimal.new(133) == Enum.at(entries, 0).value

      assert Decimal.new(133) == Enum.at(entries, 1).value

      assert Decimal.new(500) == Enum.at(entries, 2).value
      assert transient_date == Enum.at(entries, 2).date

      assert Decimal.new(133) == Enum.at(entries, 3).value
    end
  end

  describe "create_entry/1" do
    test "create regular entry" do
      %{id: account_id} = account_fixture()
      %{id: category_id} = category_fixture()

      assert {:ok,
              %{
                date: ~D[2022-01-01],
                account_id: ^account_id,
                originator_regular: %{
                  description: "a description",
                  category_id: ^category_id
                }
              }} =
               Entries.create_entry(%{
                 date: ~D[2022-01-01] |> Date.to_iso8601(),
                 account_id: account_id,
                 originator_regular: %{
                   description: "a description",
                   category_id: category_id
                 },
                 value: 200
               })
    end

    test "updates recurrency_entry if entry is parcel recurrency" do
      account = account_fixture()
      category = category_fixture()

      entry = %{
        date: ~D[2020-06-01],
        is_recurrency: true,
        account_id: account.id,
        originator_regular: %{
          description: "a description",
          category_id: category.id
        },
        value: 200,
        recurrency_entry: %{
          original_date: ~D[2020-06-01],
          recurrency: %{
            date_start: ~D[2020-06-01],
            is_parcel: true,
            parcel_start: 1,
            parcel_end: 6,
            account_id: account.id,
            frequency: :monthly,
            entry_payload: %{
              originator_regular: %{
                description: "a description",
                category_id: category.id
              },
              value: 200
            }
          }
        }
      }

      {:ok, entry} = Entries.create_entry(entry)

      assert entry.originator_regular.description == "a description"
      assert entry.recurrency_entry.parcel == 1
      assert entry.recurrency_entry.parcel_end == 6
    end
  end

  describe "delete_entry_state/1" do
    test "entry_state for an alone entry" do
      entry = entry_fixture()

      assert :regular == Entries.delete_entry_state(entry.id)
    end

    test "entry_state for a recurrency entry without future persisted" do
      recurrency = recurrency_fixture()

      entry = Enum.at(recurrency.recurrency_entries, 0).entry

      assert :recurrency == Entries.delete_entry_state(entry.id)
    end

    test "entry_state for a recurrency entry with future persisted" do
      recurrency = recurrency_fixture()

      {:ok, _} =
        recurrency
        |> Entries.recurrency_entries(Timex.today() |> Timex.shift(months: 1))
        |> Enum.at(0)
        |> Entries.create_entry(%{})

      entry = Enum.at(recurrency.recurrency_entries, 0).entry

      assert :recurrency_with_future == Entries.delete_entry_state(entry.id)
    end

    test "entry_state for a recurrency transient entry with future persisted" do
      recurrency = recurrency_fixture()

      entries = Entries.recurrency_entries(recurrency, Timex.today() |> Timex.shift(months: 4))

      {:ok, _} =
        entries
        |> Enum.at(3)
        |> Entries.create_entry(%{})

      assert :recurrency_with_future == Entries.delete_entry_state(Enum.at(entries, 1).id)
    end
  end

  describe "delete_entry/2" do
    test "delete_entry mode entry for an alone entry" do
      entry = entry_fixture()

      assert {:ok, %{delete_entry: _entry, nulify_recurrency_entry: {0, nil}}} =
               Entries.delete_entry(entry.id, "entry")
    end

    test "delete_entry mode entry for a recurrency entry" do
      recurrency = recurrency_fixture()
      entry = Enum.at(recurrency.recurrency_entries, 0).entry

      assert {:ok, %{delete_entry: {1, nil}, nulify_recurrency_entry: {1, nil}}} =
               Entries.delete_entry(entry.id, "entry")

      assert is_nil(Entries.get_recurrency!(recurrency.id).date_end)
    end

    test "delete_entry mode recurrency-keep-future for a recurrency entry" do
      recurrency = recurrency_fixture()
      entry = Enum.at(recurrency.recurrency_entries, 0).entry

      [transient] =
        Entries.recurrency_entries(recurrency, Timex.today() |> Timex.shift(months: 1))

      {:ok, persisted} = Entries.create_entry(transient, %{})

      assert {:ok,
              %{
                delete_entry: {1, nil},
                nulify_recurrency_entry: {1, nil},
                recurrency: %Entries.Recurrency{}
              }} = Entries.delete_entry(entry.id, "recurrency-keep-future")

      assert Entries.get_recurrency!(recurrency.id).date_end ==
               Timex.today() |> Timex.shift(days: -1)

      assert Entries.get_entry!(persisted.id)
      refute Entries.get_entry!(entry.id)
    end

    test "delete_entry mode recurrency-all for a recurrency entry" do
      recurrency = recurrency_fixture()
      entry = Enum.at(recurrency.recurrency_entries, 0).entry

      [transient] =
        Entries.recurrency_entries(recurrency, Timex.today() |> Timex.shift(months: 1))

      {:ok, persisted} = Entries.create_entry(transient, %{})

      assert {:ok,
              %{
                delete_entry: {2, nil},
                nulify_recurrency_entry: {2, nil},
                recurrency: %Entries.Recurrency{}
              }} = Entries.delete_entry(entry.id, "recurrency-all")

      assert Entries.get_recurrency!(recurrency.id).date_end ==
               Timex.today() |> Timex.shift(days: -1)

      refute Entries.get_entry!(persisted.id)
      refute Entries.get_entry!(entry.id)
    end

    test "delete_entry mode entry for a transient recurrency entry" do
      recurrency = recurrency_fixture()

      [transient] =
        Entries.recurrency_entries(recurrency, Timex.today() |> Timex.shift(months: 1))

      assert {:ok, %{delete_entry: {1, nil}, nulify_recurrency_entry: {1, nil}, entry: %{id: id}}} =
               Entries.delete_entry(transient.id, "entry")

      assert is_integer(id)
    end

    test "delete_entry mode recurrency-keep-future for a transient recurrency entry" do
      recurrency = recurrency_fixture()

      [transient, future] =
        Entries.recurrency_entries(recurrency, Timex.today() |> Timex.shift(months: 2))

      {:ok, persisted} = Entries.create_entry(future, %{})

      assert {:ok,
              %{
                delete_entry: {1, nil},
                nulify_recurrency_entry: {1, nil},
                recurrency: %Entries.Recurrency{}
              }} = Entries.delete_entry(transient.id, "recurrency-keep-future")

      recurrency = Entries.get_recurrency!(recurrency.id)

      assert recurrency.date_end ==
               Timex.today() |> Timex.shift(months: 1) |> Timex.shift(days: -1)

      assert Entries.get_entry!(persisted.id)

      assert [
               %{entry_id: true, original_date: Timex.today()},
               %{entry_id: true, original_date: Timex.today() |> Timex.shift(months: 2)},
               %{entry_id: false, original_date: Timex.today() |> Timex.shift(months: 1)}
             ] ==
               Enum.map(
                 recurrency.recurrency_entries,
                 &%{entry_id: not is_nil(&1.entry_id), original_date: &1.original_date}
               )
    end
  end

  describe "create_category/2" do
    test "create root category" do
      assert {:ok, %Category{name: "root"}} = Entries.create_category(%{name: "root"})
    end

    test "create child category" do
      {:ok, %{id: id} = parent} = Entries.create_category(%{name: "root"})

      assert {:ok, %{name: "child", path: [^id]}} =
               Entries.create_category(%{name: "child"}, parent)
    end
  end

  describe "list_categories_arranged/0" do
    test "list all categoris" do
      {:ok, %{id: id_root} = root} = Entries.create_category(%{name: "root"})
      {:ok, %{id: id_parent} = parent} = Entries.create_category(%{name: "parent"}, root)

      assert {:ok, %{name: "child", path: [^id_root, ^id_parent]}} =
               Entries.create_category(%{name: "child"}, parent)

      assert [
               %{name: "root"} = root,
               %{name: "parent"} = parent,
               %{name: "child"} = child
             ] = root |> Category.subtree() |> Budget.Repo.all()

      assert [
               {^root,
                [
                  {^parent,
                   [
                     {^child, []}
                   ]}
                ]}
             ] = Entries.list_categories_arranged()
    end
  end
end

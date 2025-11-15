defmodule Budget.Transactions.Transaction.FormTest do
  use Budget.DataCase, async: true

  import Budget.TransactionsFixtures

  alias Ecto.Changeset
  alias Budget.Transactions
  alias Budget.Transactions.Transaction.Form

  setup do
    [account_id: account_fixture().id, category_id: category_fixture().id]
  end

  describe "insert_changeset/1" do
    test "invalid regular transaction" do
      changeset = Form.insert_changeset(%{})

      assert %{
               account_id: ["can't be blank"],
               date: ["can't be blank"],
               value: ["can't be blank"],
               regular: ["can't be blank"],
               originator: ["can't be blank"]
             } == errors_on(changeset)

      changeset =
        Form.insert_changeset(%{
          originator: "regular",
          regular: %{}
        })

      assert %{
               account_id: ["can't be blank"],
               date: ["can't be blank"],
               value: ["can't be blank"],
               regular: %{
                 category_id: ["can't be blank"],
                 description: ["can't be blank"]
               }
             } == errors_on(changeset)
    end

    test "invalid transfer transaction" do
      changeset = Form.insert_changeset(%{originator: "transfer"})

      assert %{
               account_id: ["can't be blank"],
               date: ["can't be blank"],
               value: ["can't be blank"],
               transfer: ["can't be blank"]
             } == errors_on(changeset)

      changeset = Form.insert_changeset(%{originator: "transfer", transfer: %{}})

      assert %{
               account_id: ["can't be blank"],
               date: ["can't be blank"],
               value: ["can't be blank"],
               transfer: %{
                 other_account_id: ["can't be blank"]
               }
             } == errors_on(changeset)

      changeset =
        Form.insert_changeset(%{
          originator: "transfer",
          account_id: 1,
          transfer: %{other_account_id: 1}
        })

      assert %{
               date: ["can't be blank"],
               value: ["can't be blank"],
               transfer: %{
                 other_account_id: ["can't be the same as the origin"]
               }
             } == errors_on(changeset)
    end

    test "invalid recurrency regular transaction" do
      changeset = Form.insert_changeset(%{originator: "regular", recurrency: %{}})

      assert %{
               account_id: ["can't be blank"],
               date: ["can't be blank"],
               value: ["can't be blank"],
               regular: ["can't be blank"],
               recurrency: %{
                 type: ["can't be blank"]
               }
             } == errors_on(changeset)

      changeset =
        Form.insert_changeset(%{
          originator: "regular",
          recurrency: %{
            type: :until_date
          }
        })

      assert %{
               account_id: ["can't be blank"],
               date: ["can't be blank"],
               value: ["can't be blank"],
               regular: ["can't be blank"],
               recurrency: %{
                 date_end: ["can't be blank"]
               }
             } == errors_on(changeset)

      changeset =
        Form.insert_changeset(%{
          originator: "regular",
          recurrency: %{
            type: :parcel
          }
        })

      assert %{
               account_id: ["can't be blank"],
               date: ["can't be blank"],
               value: ["can't be blank"],
               regular: ["can't be blank"],
               recurrency: %{
                 parcel_end: ["can't be blank"],
                 parcel_start: ["can't be blank"]
               }
             } == errors_on(changeset)

      changeset =
        Form.insert_changeset(%{
          originator: "regular",
          recurrency: %{
            type: :until_date
          }
        })

      assert %{
               account_id: ["can't be blank"],
               date: ["can't be blank"],
               value: ["can't be blank"],
               regular: ["can't be blank"],
               recurrency: %{
                 date_end: ["can't be blank"]
               }
             } == errors_on(changeset)
    end

    test "insert valid regular transaction", data do
      changeset =
        Form.insert_changeset(%{
          date: ~D[2022-01-01],
          account_id: data.account_id,
          value: 200,
          originator: "regular",
          regular: %{
            category_id: data.category_id,
            description: "Something"
          }
        })

      assert %{} == errors_on(changeset)

      assert {:ok,
              %{
                account_id: _,
                date: ~D[2022-01-01],
                value: 200.0,
                originator: %{
                  category_id: _,
                  description: "Something"
                }
              }} = Form.apply_insert(changeset) |> simplify()
    end

    test "insert valid transfer transaction", data do
      other_account_id = account_fixture().id

      changeset =
        Form.insert_changeset(%{
          date: ~D[2022-01-01],
          account_id: data.account_id,
          value: 200,
          originator: "transfer",
          transfer: %{
            other_account_id: other_account_id
          }
        })

      assert %{} == errors_on(changeset)

      assert {:ok,
              %{
                account_id: _,
                date: ~D[2022-01-01],
                value: 200.0,
                originator: %{
                  other_account_id: ^other_account_id,
                  other_value: -200.0
                }
              }} = Form.apply_insert(changeset) |> simplify()
    end

    test "insert regular recurrency transaction", data do
      changeset =
        Form.insert_changeset(%{
          date: ~D[2022-01-01],
          account_id: data.account_id,
          value: 200,
          originator: "regular",
          regular: %{
            category_id: data.category_id,
            description: "Something"
          },
          recurrency: %{
            type: :until_date,
            date_end: ~D[2022-12-01],
            frequency: :monthly
          }
        })

      assert %{} == errors_on(changeset)

      assert {:ok,
              %{
                account_id: data.account_id,
                date: ~D[2022-01-01],
                value: 200.0,
                paid: true,
                originator: %{
                  category_id: data.category_id,
                  description: "Something"
                },
                recurrency: %{
                  date_end: ~D[2022-12-01],
                  date_start: ~D[2022-01-01],
                  transaction_payload: %{
                    "2022-01-01" => %{
                      "account_id" => data.account_id,
                      "category_id" => data.category_id,
                      "description" => "Something",
                      "originator" => "Elixir.Budget.Transactions.Originator.Regular",
                      "value" => "200"
                    }
                  },
                  frequency: :monthly,
                  type: :until_date,
                  parcel_end: nil,
                  parcel_start: nil
                },
                recurrency_transaction: %{
                  original_date: ~D[2022-01-01],
                  parcel: nil,
                  parcel_end: nil
                }
              }} == Form.apply_insert(changeset) |> simplify()
    end

    test "insert transfer recurrency transaction", data do
      other_account_id = account_fixture().id

      changeset =
        Form.insert_changeset(%{
          date: ~D[2022-01-01],
          account_id: data.account_id,
          value: 200,
          originator: "transfer",
          transfer: %{
            other_account_id: other_account_id
          },
          recurrency: %{
            type: :until_date,
            date_end: ~D[2022-12-01],
            frequency: :monthly
          }
        })

      assert %{} == errors_on(changeset)

      assert {:ok,
              %{
                account_id: data.account_id,
                date: ~D[2022-01-01],
                value: 200.0,
                paid: true,
                originator: %{
                  date: ~D[2022-01-01],
                  other_account_id: other_account_id,
                  other_value: -200.0
                },
                recurrency: %{
                  date_end: ~D[2022-12-01],
                  date_start: ~D[2022-01-01],
                  transaction_payload: %{
                    "2022-01-01" => %{
                      "originator" => "Elixir.Budget.Transactions.Originator.Transfer",
                      "value" => "200",
                      "counter_part_account_id" => other_account_id,
                      "part_account_id" => data.account_id
                    }
                  },
                  frequency: :monthly,
                  type: :until_date,
                  parcel_end: nil,
                  parcel_start: nil
                },
                recurrency_transaction: %{
                  original_date: ~D[2022-01-01],
                  parcel: nil,
                  parcel_end: nil
                }
              }} == Form.apply_insert(changeset) |> simplify()
    end

    test "automatically creates recurrency using /", data do
      account_fixture()

      changeset =
        Form.insert_changeset(%{
          date: ~D[2022-01-01],
          account_id: data.account_id,
          value: "200 / 2",
          originator: "regular",
          regular: %{
            category_id: data.category_id,
            description: "Something"
          }
        })

      assert %{} == errors_on(changeset)

      assert "A recurrency with 2 parcels with value 100 will be created, totalizing 200,00" ==
               Changeset.get_field(changeset, :recurrency_description)

      assert {:ok,
              %{
                value: 100.0,
                date: ~D[2022-01-01],
                account_id: data.account_id,
                originator: %{
                  description: "Something",
                  category_id: data.category_id
                },
                recurrency: %{
                  type: :parcel,
                  date_end: nil,
                  parcel_start: 1,
                  parcel_end: 2,
                  frequency: :monthly,
                  date_start: ~D[2022-01-01],
                  transaction_payload: %{
                    "2022-01-01" => %{
                      "account_id" => data.account_id,
                      "category_id" => data.category_id,
                      "description" => "Something",
                      "originator" => "Elixir.Budget.Transactions.Originator.Regular",
                      "value" => "100"
                    }
                  }
                },
                paid: true,
                recurrency_transaction: %{
                  parcel: 1,
                  parcel_end: 2,
                  original_date: ~D[2022-01-01]
                }
              }} == Form.apply_insert(changeset) |> simplify()
    end

    test "automatically creates recurrency using *", data do
      account_fixture()

      changeset =
        Form.insert_changeset(%{
          date: ~D[2022-01-01],
          account_id: data.account_id,
          value: "200 * 2",
          originator: "regular",
          regular: %{
            category_id: data.category_id,
            description: "Something"
          }
        })

      assert %{} == errors_on(changeset)

      assert "A recurrency with 2 parcels with value 200 will be created, totalizing 400,00" ==
               Changeset.get_field(changeset, :recurrency_description)

      assert {:ok,
              %{
                value: 200.0,
                date: ~D[2022-01-01],
                account_id: data.account_id,
                originator: %{
                  description: "Something",
                  category_id: data.category_id
                },
                recurrency: %{
                  type: :parcel,
                  date_end: nil,
                  parcel_start: 1,
                  parcel_end: 2,
                  frequency: :monthly,
                  date_start: ~D[2022-01-01],
                  transaction_payload: %{
                    "2022-01-01" => %{
                      "account_id" => data.account_id,
                      "category_id" => data.category_id,
                      "description" => "Something",
                      "originator" => "Elixir.Budget.Transactions.Originator.Regular",
                      "value" => "200"
                    }
                  }
                },
                paid: true,
                recurrency_transaction: %{
                  parcel: 1,
                  parcel_end: 2,
                  original_date: ~D[2022-01-01]
                }
              }} == Form.apply_insert(changeset) |> simplify()
    end
  end

  describe "update_changeset/2" do
    test "invalid regular transaction", data do
      {:ok, transaction} =
        %{
          date: ~D[2022-01-01],
          account_id: data.account_id,
          value: 200,
          originator: "regular",
          regular: %{
            category_id: data.category_id,
            description: "Something"
          }
        }
        |> Form.insert_changeset()
        |> Form.apply_insert()

      form = Form.decorate(transaction)

      assert %Budget.Transactions.Transaction.Form{
               account_id: data.account_id,
               date: ~D[2022-01-01],
               id: transaction.id,
               paid: true,
               is_recurrency: false,
               originator: "regular",
               recurrency: nil,
               apply_forward: false,
               regular: %Budget.Transactions.Transaction.Form.RegularForm{
                 id: nil,
                 category_id: data.category_id,
                 description: "Something"
               },
               transfer: nil,
               value: Decimal.new(200),
               position: Decimal.new(1)
             } == form

      changeset =
        Form.update_changeset(form, %{
          date: nil,
          account_id: nil,
          paid: nil,
          value: nil,
          regular: %{
            description: "",
            category_id: nil
          }
        })

      assert %{
               account_id: ["can't be blank"],
               date: ["can't be blank"],
               paid: ["can't be blank"],
               regular: %{category_id: ["can't be blank"], description: ["can't be blank"]},
               value: ["can't be blank"]
             } == errors_on(changeset)
    end

    test "invalid transfer transaction", data do
      other_account_id = account_fixture().id

      {:ok, transaction} =
        %{
          date: ~D[2022-01-01],
          account_id: data.account_id,
          value: 200,
          originator: "transfer",
          transfer: %{
            other_account_id: other_account_id
          }
        }
        |> Form.insert_changeset()
        |> Form.apply_insert()

      form = Form.decorate(transaction)

      assert %Budget.Transactions.Transaction.Form{
               account_id: data.account_id,
               date: ~D[2022-01-01],
               id: transaction.id,
               paid: true,
               is_recurrency: false,
               originator: "transfer",
               recurrency: nil,
               apply_forward: false,
               transfer: %Budget.Transactions.Transaction.Form.TransferForm{
                 other_account_id: other_account_id
               },
               value: Decimal.new(200),
               position: Decimal.new(1)
             } == form

      changeset =
        Form.update_changeset(form, %{
          date: nil,
          account_id: nil,
          paid: nil,
          value: nil,
          transfer: %{
            other_account_id: nil
          }
        })

      assert %{
               account_id: ["can't be blank"],
               date: ["can't be blank"],
               paid: ["can't be blank"],
               transfer: %{other_account_id: ["can't be blank"]},
               value: ["can't be blank"]
             } == errors_on(changeset)
    end

    test "update valid regular transaction", data do
      {:ok, transaction} =
        %{
          date: ~D[2022-01-01],
          account_id: data.account_id,
          value: 200,
          originator: "regular",
          paid: true,
          regular: %{
            category_id: data.category_id,
            description: "Something"
          }
        }
        |> Form.insert_changeset()
        |> Form.apply_insert()

      other_account_id = account_fixture().id
      other_category_id = category_fixture().id

      {:ok, transaction} =
        transaction
        |> Form.decorate()
        |> Form.update_changeset(%{
          date: ~D[2022-02-02],
          account_id: other_account_id,
          value: 300,
          paid: true,
          regular: %{
            category_id: other_category_id,
            description: "Something updated"
          }
        })
        |> Form.apply_update(transaction)

      assert %{
               account_id: other_account_id,
               date: ~D[2022-02-02],
               originator: %{category_id: other_category_id, description: "Something updated"},
               value: 300.0,
               paid: true
             } == transaction |> simplify()
    end

    test "update valid transfer part transaction", data do
      other_account_id = account_fixture().id

      {:ok, transaction} =
        %{
          date: ~D[2022-01-01],
          account_id: data.account_id,
          value: 200,
          originator: "transfer",
          paid: true,
          transfer: %{
            other_account_id: other_account_id
          }
        }
        |> Form.insert_changeset()
        |> Form.apply_insert()

      other_account_id_part = account_fixture().id
      other_account_id_counter_part = account_fixture().id

      {:ok, transaction} =
        transaction
        |> Form.decorate()
        |> Form.update_changeset(%{
          date: ~D[2022-02-02],
          account_id: other_account_id_part,
          value: 300,
          paid: true,
          transfer: %{
            other_account_id: other_account_id_counter_part
          }
        })
        |> Form.apply_update(transaction)

      assert %{
               account_id: other_account_id_part,
               date: ~D[2022-02-02],
               originator: %{
                 date: ~D[2022-02-02],
                 other_account_id: other_account_id_counter_part,
                 other_value: -300.0
               },
               paid: true,
               value: 300.0
             } == transaction |> simplify()

      assert %{
               account_id: other_account_id_counter_part,
               date: ~D[2022-02-02],
               originator: %{
                 other_account_id: other_account_id_part,
                 date: ~D[2022-02-02],
                 other_value: 300.0
               },
               paid: true,
               value: -300.0
             } ==
               transaction.originator_transfer_part.counter_part.id
               |> Transactions.get_transaction!()
               |> simplify()
    end

    test "update valid transfer counter part transaction", data do
      other_account_id = account_fixture().id

      {:ok, transaction} =
        %{
          date: ~D[2022-01-01],
          account_id: data.account_id,
          value: 200,
          originator: "transfer",
          transfer: %{
            other_account_id: other_account_id
          }
        }
        |> Form.insert_changeset()
        |> Form.apply_insert()

      counter_part_transaction =
        Transactions.get_transaction!(transaction.originator_transfer_part.counter_part.id)

      other_account_id_part = account_fixture().id
      other_account_id_counter_part = account_fixture().id

      {:ok, counter_part_transaction} =
        counter_part_transaction
        |> Form.decorate()
        |> Form.update_changeset(%{
          date: ~D[2022-02-02],
          account_id: other_account_id_part,
          value: 300,
          paid: true,
          transfer: %{
            other_account_id: other_account_id_counter_part
          }
        })
        |> Form.apply_update(counter_part_transaction)

      assert %{
               account_id: other_account_id_part,
               date: ~D[2022-02-02],
               originator: %{
                 date: ~D[2022-02-02],
                 other_account_id: other_account_id_counter_part,
                 other_value: -300.0
               },
               value: 300.0,
               paid: true
             } == counter_part_transaction |> simplify()
    end

    test "update valid recurrency regular transaction not applying forward", data do
      {:ok, transaction} =
        %{
          date: ~D[2022-01-01],
          account_id: data.account_id,
          value: 200,
          originator: "regular",
          regular: %{
            category_id: data.category_id,
            description: "Something"
          },
          recurrency: %{
            type: :until_date,
            date_end: ~D[2022-12-01],
            frequency: :monthly
          }
        }
        |> Form.insert_changeset()
        |> Form.apply_insert()

      other_account_id = account_fixture().id
      other_category_id = category_fixture().id

      {:ok, transaction} =
        transaction
        |> Form.decorate()
        |> Form.update_changeset(%{
          date: ~D[2022-02-02],
          account_id: other_account_id,
          value: 300,
          apply_forward: false,
          regular: %{
            category_id: other_category_id,
            description: "Something updated"
          }
        })
        |> Form.apply_update(transaction)

      assert %{
               account_id: other_account_id,
               date: ~D[2022-02-02],
               originator: %{category_id: other_category_id, description: "Something updated"},
               value: 300.0,
               paid: true,
               recurrency: %{
                 date_end: ~D[2022-12-01],
                 date_start: ~D[2022-01-01],
                 transaction_payload: %{
                   "2022-01-01" => %{
                     "account_id" => data.account_id,
                     "category_id" => data.category_id,
                     "description" => "Something",
                     "originator" => "Elixir.Budget.Transactions.Originator.Regular",
                     "value" => "200"
                   }
                 },
                 frequency: :monthly,
                 type: :until_date,
                 parcel_end: nil,
                 parcel_start: nil
               },
               recurrency_transaction: %{
                 original_date: ~D[2022-01-01],
                 parcel: nil,
                 parcel_end: nil
               }
             } == transaction |> simplify()
    end

    test "should finalize recurrency when adding last parcel", data do
      recurrency = recurrency_fixture(%{
        date: ~D[2019-01-01],
        regular: %{
          description: "Some description",
          category_id: category_fixture().id
        },
        value: 200,
        recurrency: %{
          type: :parcel,
          parcel_start: 1,
          parcel_end: 3
        }
      })

      transactions = Transactions.transactions_in_period(~D[2019-01-01], ~D[2019-03-01])

      persist(Enum.at(transactions, 1))

      assert true == Transactions.get_recurrency!(recurrency.id).active 

      persist(Enum.at(transactions, 2))

      assert false == Transactions.get_recurrency!(recurrency.id).active 
    end

    test "update valid recurrency regular transaction applying forward", data do
      {:ok, transaction} =
        %{
          date: ~D[2022-01-01],
          account_id: data.account_id,
          value: 200,
          originator: "regular",
          regular: %{
            category_id: data.category_id,
            description: "Something"
          },
          recurrency: %{
            type: :until_date,
            date_end: ~D[2022-12-01],
            frequency: :monthly
          }
        }
        |> Form.insert_changeset()
        |> Form.apply_insert()

      other_account_id = account_fixture().id
      other_category_id = category_fixture().id

      {:ok, transaction} =
        transaction
        |> Form.decorate()
        |> Form.update_changeset(%{
          date: ~D[2022-02-02],
          account_id: other_account_id,
          value: 300,
          apply_forward: true,
          regular: %{
            category_id: other_category_id,
            description: "Something updated"
          }
        })
        |> Form.apply_update(transaction)

      assert %{
               account_id: other_account_id,
               date: ~D[2022-02-02],
               originator: %{category_id: other_category_id, description: "Something updated"},
               value: 300.0,
               paid: true,
               recurrency: %{
                 date_end: ~D[2022-12-01],
                 date_start: ~D[2022-01-01],
                 transaction_payload: %{
                   "2022-01-01" => %{
                     "account_id" => other_account_id,
                     "category_id" => other_category_id,
                     "description" => "Something updated",
                     "originator" => "Elixir.Budget.Transactions.Originator.Regular",
                     "value" => "300"
                   }
                 },
                 frequency: :monthly,
                 type: :until_date,
                 parcel_end: nil,
                 parcel_start: nil
               },
               recurrency_transaction: %{
                 original_date: ~D[2022-01-01],
                 parcel: nil,
                 parcel_end: nil
               }
             } == transaction |> simplify()
    end

    test "update valid transfer part transaction applying forward", data do
      other_account_id = account_fixture().id

      {:ok, transaction} =
        %{
          date: ~D[2022-01-01],
          account_id: data.account_id,
          value: 200,
          originator: "transfer",
          transfer: %{
            other_account_id: other_account_id
          },
          recurrency: %{
            type: :until_date,
            date_end: ~D[2022-12-01],
            frequency: :monthly
          }
        }
        |> Form.insert_changeset()
        |> Form.apply_insert()

      other_account_id_part = account_fixture().id
      other_account_id_counter_part = account_fixture().id

      {:ok, transaction} =
        transaction
        |> Form.decorate()
        |> Form.update_changeset(%{
          date: ~D[2022-02-02],
          account_id: other_account_id_part,
          value: 300,
          apply_forward: true,
          transfer: %{
            other_account_id: other_account_id_counter_part
          }
        })
        |> Form.apply_update(transaction)

      assert %{
               account_id: other_account_id_part,
               date: ~D[2022-02-02],
               originator: %{
                 date: ~D[2022-02-02],
                 other_account_id: other_account_id_counter_part,
                 other_value: -300.0
               },
               value: 300.0,
               paid: true,
               recurrency: %{
                 date_end: ~D[2022-12-01],
                 date_start: ~D[2022-01-01],
                 transaction_payload: %{
                   "2022-01-01" => %{
                     "counter_part_account_id" => other_account_id_counter_part,
                     "originator" => "Elixir.Budget.Transactions.Originator.Transfer",
                     "part_account_id" => other_account_id_part,
                     "value" => "300"
                   }
                 },
                 frequency: :monthly,
                 type: :until_date,
                 parcel_end: nil,
                 parcel_start: nil
               },
               recurrency_transaction: %{
                 original_date: ~D[2022-01-01],
                 parcel: nil,
                 parcel_end: nil
               }
             } == transaction |> simplify()
    end

    test "update valid transfer counter part transaction applying forward", data do
      other_account_id = account_fixture().id

      {:ok, transaction} =
        %{
          date: ~D[2022-01-01],
          account_id: data.account_id,
          value: 200,
          originator: "transfer",
          transfer: %{
            other_account_id: other_account_id
          },
          recurrency: %{
            type: :until_date,
            date_end: ~D[2022-12-01],
            frequency: :monthly
          }
        }
        |> Form.insert_changeset()
        |> Form.apply_insert()

      counter_part_transaction =
        Transactions.get_transaction!(transaction.originator_transfer_part.counter_part.id)

      other_account_id_part = account_fixture().id
      other_account_id_counter_part = account_fixture().id

      {:ok, counter_part_transaction} =
        counter_part_transaction
        |> Form.decorate()
        |> Form.update_changeset(%{
          date: ~D[2022-02-02],
          account_id: other_account_id_part,
          value: 300,
          apply_forward: true,
          transfer: %{
            other_account_id: other_account_id_counter_part
          }
        })
        |> Form.apply_update(counter_part_transaction)

      assert %{
               account_id: other_account_id_part,
               date: ~D[2022-02-02],
               originator: %{
                 date: ~D[2022-02-02],
                 other_account_id: other_account_id_counter_part,
                 other_value: -300.0
               },
               value: 300.0,
               paid: true,
               recurrency: %{
                 date_end: ~D[2022-12-01],
                 date_start: ~D[2022-01-01],
                 transaction_payload: %{
                   "2022-01-01" => %{
                     "counter_part_account_id" => other_account_id_part,
                     "originator" => "Elixir.Budget.Transactions.Originator.Transfer",
                     "part_account_id" => other_account_id_counter_part,
                     "value" => "300"
                   }
                 },
                 frequency: :monthly,
                 type: :until_date,
                 parcel_end: nil,
                 parcel_start: nil
               },
               recurrency_transaction: %{
                 original_date: ~D[2022-01-01],
                 parcel: nil,
                 parcel_end: nil
               }
             } == counter_part_transaction |> simplify()
    end

    test "update valid recurrency regular transaction applying forward in a transient transaction",
         data do
      {:ok, _} =
        %{
          date: ~D[2022-01-01],
          account_id: data.account_id,
          value: 200,
          originator: "regular",
          regular: %{
            category_id: data.category_id,
            description: "Something"
          },
          recurrency: %{
            type: :until_date,
            date_end: ~D[2022-12-01],
            frequency: :monthly
          }
        }
        |> Form.insert_changeset()
        |> Form.apply_insert()

      [transaction] = Transactions.transactions_in_period(~D[2022-02-01], ~D[2022-02-01])

      other_account_id = account_fixture().id
      other_category_id = category_fixture().id

      {:ok, transaction} =
        transaction
        |> Form.decorate()
        |> Form.update_changeset(%{
          date: ~D[2022-02-02],
          account_id: other_account_id,
          value: 300,
          apply_forward: true,
          regular: %{
            category_id: other_category_id,
            description: "Something updated"
          }
        })
        |> Form.apply_update(transaction)

      assert %{
               account_id: other_account_id,
               date: ~D[2022-02-02],
               originator: %{category_id: other_category_id, description: "Something updated"},
               value: 300.0,
               paid: true,
               recurrency: %{
                 date_end: ~D[2022-12-01],
                 date_start: ~D[2022-01-01],
                 transaction_payload: %{
                   "2022-01-01" => %{
                     "account_id" => data.account_id,
                     "category_id" => data.category_id,
                     "description" => "Something",
                     "originator" => "Elixir.Budget.Transactions.Originator.Regular",
                     "value" => "200"
                   },
                   "2022-02-01" => %{
                     "account_id" => other_account_id,
                     "category_id" => other_category_id,
                     "description" => "Something updated",
                     "originator" => "Elixir.Budget.Transactions.Originator.Regular",
                     "value" => "300"
                   }
                 },
                 frequency: :monthly,
                 type: :until_date,
                 parcel_end: nil,
                 parcel_start: nil
               },
               recurrency_transaction: %{
                 original_date: ~D[2022-02-01],
                 parcel: nil,
                 parcel_end: nil
               }
             } == transaction |> simplify()
    end

    test "adjust position when updating date" do
      t_1 = transaction_fixture(%{date: Timex.today()})
      t_2 = transaction_fixture(%{date: Timex.today() |> Timex.shift(days: 1)})
      t_3 = transaction_fixture(%{date: Timex.today() |> Timex.shift(days: 2)})

      assert Decimal.new(1) == t_1.position
      assert Decimal.new(1) == t_2.position
      assert Decimal.new(1) == t_3.position

      {:ok, t_2} =
        t_2
        |> Form.decorate()
        |> Form.update_changeset(%{
          date: Timex.today()
        })
        |> Form.apply_update(t_2)

      assert Decimal.new(2) == t_2.position

      {:ok, t_3} =
        t_3
        |> Form.decorate()
        |> Form.update_changeset(%{
          date: Timex.today()
        })
        |> Form.apply_update(t_3)

      assert Decimal.new(3) == t_3.position
    end
  end
end

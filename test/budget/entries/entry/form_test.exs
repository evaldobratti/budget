defmodule Budget.Entries.Entry.FormTest do
  use Budget.DataCase, async: true

  import Budget.EntriesFixtures

  alias Budget.Entries
  alias Budget.Entries.Entry.Form
  alias Budget.Entries.Entry

  def simplify(%Entry{} = transaction) do
    originator =
      case transaction do
        %{originator_regular_id: id} when is_integer(id) ->
          %{
            description: transaction.originator_regular.description,
            category_id: transaction.originator_regular.category_id
          }

        %{originator_transfer_part_id: id} when is_integer(id) ->
          %{
            date: transaction.originator_transfer_part.counter_part.date,
            other_account_id: transaction.originator_transfer_part.counter_part.account_id,
            other_value:
              transaction.originator_transfer_part.counter_part.value |> Decimal.to_float()
          }

        %{originator_transfer_counter_part_id: id} when is_integer(id) ->
          %{
            date: transaction.originator_transfer_counter_part.part.date,
            other_account_id: transaction.originator_transfer_counter_part.part.account_id,
            other_value:
              transaction.originator_transfer_counter_part.part.value |> Decimal.to_float()
          }
      end

    recurrency_data =
      case transaction.recurrency_entry do
        %Ecto.Association.NotLoaded{} ->
          %{}

        nil ->
          %{}

        _ ->
          recurrency = transaction.recurrency_entry.recurrency

          %{
            recurrency_entry: %{
              original_date: transaction.recurrency_entry.original_date,
              parcel: transaction.recurrency_entry.parcel,
              parcel_end: transaction.recurrency_entry.parcel_end
            },
            recurrency: %{
              frequency: recurrency.frequency,
              date_start: recurrency.date_start,
              date_end: recurrency.date_end,
              entry_payload: recurrency.entry_payload,
              is_parcel: recurrency.is_parcel,
              parcel_start: recurrency.parcel_start,
              parcel_end: recurrency.parcel_end
            }
          }
      end

    %{
      date: transaction.date,
      account_id: transaction.account_id,
      originator: originator,
      value: Decimal.to_float(transaction.value)
    }
    |> Map.merge(recurrency_data)
  end

  def simplify({:ok, %Entry{} = transaction}) do
    {:ok, simplify(transaction)}
  end

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
    end

    test "invalid recurrency regular transaction" do
      changeset = Form.insert_changeset(%{originator: "regular", recurrency: %{}})

      assert %{
               account_id: ["can't be blank"],
               date: ["can't be blank"],
               value: ["can't be blank"],
               regular: ["can't be blank"],
               recurrency: %{
                 date_end: ["can't be blank"],
                 is_parcel: ["can't be blank"],
                 is_forever: ["can't be blank"],
                 frequency: ["can't be blank"]
               }
             } == errors_on(changeset)

      changeset =
        Form.insert_changeset(%{
          originator: "regular",
          recurrency: %{
            is_forever: false
          }
        })

      assert %{
               account_id: ["can't be blank"],
               date: ["can't be blank"],
               value: ["can't be blank"],
               regular: ["can't be blank"],
               recurrency: %{
                 date_end: ["can't be blank"],
                 is_parcel: ["can't be blank"],
                 frequency: ["can't be blank"]
               }
             } == errors_on(changeset)

      changeset =
        Form.insert_changeset(%{
          originator: "regular",
          recurrency: %{
            is_forever: false,
            is_parcel: true
          }
        })

      assert %{
               account_id: ["can't be blank"],
               date: ["can't be blank"],
               value: ["can't be blank"],
               regular: ["can't be blank"],
               recurrency: %{
                 parcel_end: ["can't be blank"],
                 parcel_start: ["can't be blank"],
                 frequency: ["can't be blank"]
               }
             } == errors_on(changeset)

      changeset =
        Form.insert_changeset(%{
          originator: "regular",
          recurrency: %{
            is_forever: false,
            is_parcel: false
          }
        })

      assert %{
               account_id: ["can't be blank"],
               date: ["can't be blank"],
               value: ["can't be blank"],
               regular: ["can't be blank"],
               recurrency: %{
                 frequency: ["can't be blank"],
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
            is_parcel: false,
            is_forever: false,
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
                originator: %{
                  category_id: data.category_id,
                  description: "Something"
                },
                recurrency: %{
                  date_end: ~D[2022-12-01],
                  date_start: ~D[2022-01-01],
                  entry_payload: %{
                    "2022-01-01" => %{
                      "account_id" => data.account_id,
                      "category_id" => data.category_id,
                      "description" => "Something",
                      "originator" => "Elixir.Budget.Entries.Originator.Regular",
                      "value" => "200"
                    }
                  },
                  frequency: :monthly,
                  is_parcel: false,
                  parcel_end: nil,
                  parcel_start: nil
                },
                recurrency_entry: %{original_date: ~D[2022-01-01], parcel: nil, parcel_end: nil}
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
            is_parcel: false,
            is_forever: false,
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
                originator: %{
                  date: ~D[2022-01-01],
                  other_account_id: other_account_id,
                  other_value: -200.0
                },
                recurrency: %{
                  date_end: ~D[2022-12-01],
                  date_start: ~D[2022-01-01],
                  entry_payload: %{
                    "2022-01-01" => %{
                      "originator" => "Elixir.Budget.Entries.Originator.Transfer",
                      "value" => "200",
                      "counter_part_account_id" => other_account_id,
                      "part_account_id" => data.account_id
                    }
                  },
                  frequency: :monthly,
                  is_parcel: false,
                  parcel_end: nil,
                  parcel_start: nil
                },
                recurrency_entry: %{original_date: ~D[2022-01-01], parcel: nil, parcel_end: nil}
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

      assert %Budget.Entries.Entry.Form{
               account_id: data.account_id,
               date: ~D[2022-01-01],
               id: nil,
               is_carried_out: false,
               is_recurrency: nil,
               keep_adding: false,
               originator: "regular",
               recurrency: nil,
               apply_forward: false,
               regular: %Budget.Entries.Entry.Form.RegularForm{
                 id: nil,
                 category_id: data.category_id,
                 description: "Something"
               },
               transfer: nil,
               value: Decimal.new(200)
             } == form

      changeset =
        Form.update_changeset(form, %{
          date: nil,
          account_id: nil,
          is_carried_out: nil,
          value: nil,
          regular: %{
            description: "",
            category_id: nil
          }
        })

      assert %{
               account_id: ["can't be blank"],
               date: ["can't be blank"],
               is_carried_out: ["can't be blank"],
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

      assert %Budget.Entries.Entry.Form{
               account_id: data.account_id,
               date: ~D[2022-01-01],
               id: nil,
               is_carried_out: false,
               is_recurrency: nil,
               keep_adding: false,
               originator: "transfer",
               recurrency: nil,
               apply_forward: false,
               transfer: %Budget.Entries.Entry.Form.TransferForm{
                 other_account_id: other_account_id
               },
               value: Decimal.new(200)
             } == form

      changeset =
        Form.update_changeset(form, %{
          date: nil,
          account_id: nil,
          is_carried_out: nil,
          value: nil,
          transfer: %{
            other_account_id: nil
          }
        })

      assert %{
               account_id: ["can't be blank"],
               date: ["can't be blank"],
               is_carried_out: ["can't be blank"],
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
               value: 300.0
             } == transaction |> simplify()
    end

    test "update valid transfer part transaction", data do
      {:ok, transaction} =
        %{
          date: ~D[2022-01-01],
          account_id: data.account_id,
          value: 200,
          originator: "transfer",
          transfer: %{
            other_account_id: data.account_id
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
               value: 300.0
             } == transaction |> simplify()
    end

    test "update valid transfer counter part transaction", data do
      {:ok, transaction} =
        %{
          date: ~D[2022-01-01],
          account_id: data.account_id,
          value: 200,
          originator: "transfer",
          transfer: %{
            other_account_id: data.account_id
          }
        }
        |> Form.insert_changeset()
        |> Form.apply_insert()

      counter_part_transaction =
        Entries.get_entry!(transaction.originator_transfer_part.counter_part.id)

      other_account_id_part = account_fixture().id
      other_account_id_counter_part = account_fixture().id

      {:ok, counter_part_transaction} =
        counter_part_transaction
        |> Form.decorate()
        |> Form.update_changeset(%{
          date: ~D[2022-02-02],
          account_id: other_account_id_part,
          value: 300,
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
               value: 300.0
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
            is_parcel: false,
            is_forever: false,
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
               recurrency: %{
                 date_end: ~D[2022-12-01],
                 date_start: ~D[2022-01-01],
                 entry_payload: %{
                   "2022-01-01" => %{
                     "account_id" => data.account_id,
                     "category_id" => data.category_id,
                     "description" => "Something",
                     "originator" => "Elixir.Budget.Entries.Originator.Regular",
                     "value" => "200"
                   }
                 },
                 frequency: :monthly,
                 is_parcel: false,
                 parcel_end: nil,
                 parcel_start: nil
               },
               recurrency_entry: %{original_date: ~D[2022-01-01], parcel: nil, parcel_end: nil}
             } == transaction |> simplify()
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
            is_parcel: false,
            is_forever: false,
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
               recurrency: %{
                 date_end: ~D[2022-12-01],
                 date_start: ~D[2022-01-01],
                 entry_payload: %{
                   "2022-01-01" => %{
                     "account_id" => other_account_id,
                     "category_id" => other_category_id,
                     "description" => "Something updated",
                     "originator" => "Elixir.Budget.Entries.Originator.Regular",
                     "value" => "300"
                   }
                 },
                 frequency: :monthly,
                 is_parcel: false,
                 parcel_end: nil,
                 parcel_start: nil
               },
               recurrency_entry: %{original_date: ~D[2022-01-01], parcel: nil, parcel_end: nil}
             } == transaction |> simplify()
    end

    test "update valid transfer part transaction applying forward", data do
      {:ok, transaction} =
        %{
          date: ~D[2022-01-01],
          account_id: data.account_id,
          value: 200,
          originator: "transfer",
          transfer: %{
            other_account_id: data.account_id
          },
          recurrency: %{
            is_parcel: false,
            is_forever: false,
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
               recurrency: %{
                 date_end: ~D[2022-12-01],
                 date_start: ~D[2022-01-01],
                 entry_payload: %{
                   "2022-01-01" => %{
                     "counter_part_account_id" => other_account_id_counter_part,
                     "originator" => "Elixir.Budget.Entries.Originator.Transfer",
                     "part_account_id" => other_account_id_part,
                     "value" => "300"
                   }
                 },
                 frequency: :monthly,
                 is_parcel: false,
                 parcel_end: nil,
                 parcel_start: nil
               },
               recurrency_entry: %{original_date: ~D[2022-01-01], parcel: nil, parcel_end: nil}
             } == transaction |> simplify()
    end

    test "update valid transfer counter part transaction applying forward", data do
      {:ok, transaction} =
        %{
          date: ~D[2022-01-01],
          account_id: data.account_id,
          value: 200,
          originator: "transfer",
          transfer: %{
            other_account_id: data.account_id
          },
          recurrency: %{
            is_parcel: false,
            is_forever: false,
            date_end: ~D[2022-12-01],
            frequency: :monthly
          }
        }
        |> Form.insert_changeset()
        |> Form.apply_insert()

      counter_part_transaction =
        Entries.get_entry!(transaction.originator_transfer_part.counter_part.id)

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
               recurrency: %{
                 date_end: ~D[2022-12-01],
                 date_start: ~D[2022-01-01],
                 entry_payload: %{
                   "2022-01-01" => %{
                     "counter_part_account_id" => other_account_id_part,
                     "originator" => "Elixir.Budget.Entries.Originator.Transfer",
                     "part_account_id" => other_account_id_counter_part,
                     "value" => "300"
                   }
                 },
                 frequency: :monthly,
                 is_parcel: false,
                 parcel_end: nil,
                 parcel_start: nil
               },
               recurrency_entry: %{original_date: ~D[2022-01-01], parcel: nil, parcel_end: nil}
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
            is_parcel: false,
            is_forever: false,
            date_end: ~D[2022-12-01],
            frequency: :monthly
          }
        }
        |> Form.insert_changeset()
        |> Form.apply_insert()

      [transaction] = Entries.entries_in_period([], ~D[2022-02-01], ~D[2022-02-01])

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
               recurrency: %{
                 date_end: ~D[2022-12-01],
                 date_start: ~D[2022-01-01],
                 entry_payload: %{
                   "2022-01-01" => %{
                     "account_id" => data.account_id,
                     "category_id" => data.category_id,
                     "description" => "Something",
                     "originator" => "Elixir.Budget.Entries.Originator.Regular",
                     "value" => "200"
                   },
                   "2022-02-01" => %{
                     "account_id" => other_account_id,
                     "category_id" => other_category_id,
                     "description" => "Something updated",
                     "originator" => "Elixir.Budget.Entries.Originator.Regular",
                     "value" => "300"
                   }
                 },
                 frequency: :monthly,
                 is_parcel: false,
                 parcel_end: nil,
                 parcel_start: nil
               },
               recurrency_entry: %{original_date: ~D[2022-02-01], parcel: nil, parcel_end: nil}
             } == transaction |> simplify()
    end
  end
end

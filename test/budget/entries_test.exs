defmodule Budget.EntriesTest do
  use Budget.DataCase

  alias Budget.Entries
  alias Budget.Entries.Recurrency


  def create_account(_) do
    {:ok, account} = 
      Entries.create_account(%{
        name: "Account name",
        initial_balance: 0
      })

    {:ok, account: account}
  end

  describe "change_recurrency" do

    setup :create_account

    test "finite recurrency", %{account: account} do
      changeset =
        Entries.change_recurrency(%Recurrency{}, %{
          date_start: "2022-10-01",
          date_end: "2022-10-01",
          description: "Some description",
          value: "200",
          account_id: account.id,
          is_forever: false,
          is_parcel: false,
          frequency: :monthly
        })

      assert %{valid?: true} = changeset

      changeset = 
        Entries.change_recurrency(%Recurrency{}, %{
          date_start: "2022-10-01",
          description: "Some description",
          value: "200",
          account_id: account.id,
          is_forever: false,
          is_parcel: false,
          frequency: :monthly

        })

      assert %{valid?: false} = changeset
      assert errors_on(changeset).date_end == ["can't be blank"]
    end

    test "infinite recurrency", %{account: account} do
      changeset = 
        Entries.change_recurrency(%Recurrency{}, %{
          date_start: "2022-10-01",
          date_end: "2022-10-01",
          description: "Some description",
          value: "200",
          account_id: account.id,
          is_forever: true,
          is_parcel: false,
          frequency: :monthly
        })

      assert %{valid?: true, changes: changes} = changeset
      assert Map.get(changes, :date_end) == nil
    end

    test "infinite parcel", %{account: account} do
      changeset = 
        Entries.change_recurrency(%Recurrency{}, %{
          date_start: "2022-10-01",
          date_end: "2022-10-01",
          description: "Some description",
          value: "200",
          account_id: account.id,
          is_forever: true,
          is_parcel: true,
          frequency: :monthly
        })

      assert %{valid?: false} = changeset
      assert errors_on(changeset).is_forever == ["Recurrency can't be infinite parcel"]
    end

    test "parcel", %{account: account} do
      changeset = 
        Entries.change_recurrency(%Recurrency{}, %{
          date_start: "2022-10-01",
          is_forever: false,
          is_parcel: true,
          description: "Some description",
          frequency: :monthly,
          account_id: account.id,
          value: 200
        })

      assert %{valid?: false} = changeset
      assert errors_on(changeset) == %{
        parcel_start: ["can't be blank"],
        parcel_end: ["can't be blank"],
      }
    end

    test "calculate finite recurrency entries until date - monthly" do
      recurrency = 
        %Recurrency{
          account_id: 1,
          is_forever: false,
          description: "Some description",
          frequency: :monthly,
          value: 200,
          date_start: ~D[2019-01-01],
          date_end: ~D[2019-03-31],
        }

      assert [
        %{date: ~D[2019-01-01], value: 200, description: "Some description"}, 
        %{date: ~D[2019-02-01], value: 200, description: "Some description"},
        %{date: ~D[2019-03-01], value: 200, description: "Some description"},
      ] = Entries.recurrency_entries(recurrency, ~D[2019-03-15])

      assert [
        %{date: ~D[2019-01-01], value: 200, description: "Some description"}, 
        %{date: ~D[2019-02-01], value: 200, description: "Some description"},
        %{date: ~D[2019-03-01], value: 200, description: "Some description"},
      ] = Entries.recurrency_entries(recurrency, ~D[2019-03-01])

      assert [] = Entries.recurrency_entries(recurrency, ~D[2018-03-01])

      assert [
        %{date: ~D[2019-01-01], value: 200, description: "Some description"}, 
        %{date: ~D[2019-02-01], value: 200, description: "Some description"},
        %{date: ~D[2019-03-01], value: 200, description: "Some description"},
      ] = Entries.recurrency_entries(recurrency, ~D[2019-06-01])
    end

    test "calculate finite recurrency entries until date - weekly" do
      recurrency = 
        %Recurrency{
          account_id: 1,
          is_forever: false,
          description: "Some description",
          frequency: :weekly,
          value: 200,
          date_start: ~D[2019-01-01],
          date_end: ~D[2019-01-31],
        }

      assert [
        %{date: ~D[2019-01-01], value: 200, description: "Some description"}, 
        %{date: ~D[2019-01-08], value: 200, description: "Some description"},
        %{date: ~D[2019-01-15], value: 200, description: "Some description"},
        %{date: ~D[2019-01-22], value: 200, description: "Some description"},
        %{date: ~D[2019-01-29], value: 200, description: "Some description"},
      ] = Entries.recurrency_entries(recurrency, ~D[2019-03-15])

      assert [
        %{date: ~D[2019-01-01], value: 200, description: "Some description"}, 
        %{date: ~D[2019-01-08], value: 200, description: "Some description"},
        %{date: ~D[2019-01-15], value: 200, description: "Some description"},
      ] = Entries.recurrency_entries(recurrency, ~D[2019-01-15])

      assert [] = Entries.recurrency_entries(recurrency, ~D[2018-03-01])

      assert [
        %{date: ~D[2019-01-01], value: 200, description: "Some description"}, 
        %{date: ~D[2019-01-08], value: 200, description: "Some description"},
        %{date: ~D[2019-01-15], value: 200, description: "Some description"},
        %{date: ~D[2019-01-22], value: 200, description: "Some description"},
        %{date: ~D[2019-01-29], value: 200, description: "Some description"},
      ] = Entries.recurrency_entries(recurrency, ~D[2019-06-01])
    end
  end
  
end

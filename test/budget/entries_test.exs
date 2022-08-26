defmodule Budget.EntriesTest do
  use Budget.DataCase

  alias Budget.Entries

  describe "accounts" do
    alias Budget.Entries.Account

    import Budget.EntriesFixtures

    @invalid_attrs %{initial_balance: nil, name: nil}

    test "list_accounts/0 returns all accounts" do
      account = account_fixture()
      assert Entries.list_accounts() == [account]
    end

    test "get_account!/1 returns the account with given id" do
      account = account_fixture()
      assert Entries.get_account!(account.id) == account
    end

    test "create_account/1 with valid data creates a account" do
      valid_attrs = %{initial_balance: "120.5", name: "some name"}

      assert {:ok, %Account{} = account} = Entries.create_account(valid_attrs)
      assert account.initial_balance == Decimal.new("120.5")
      assert account.name == "some name"
    end

    test "create_account/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Entries.create_account(@invalid_attrs)
    end

    test "update_account/2 with valid data updates the account" do
      account = account_fixture()
      update_attrs = %{initial_balance: "456.7", name: "some updated name"}

      assert {:ok, %Account{} = account} = Entries.update_account(account, update_attrs)
      assert account.initial_balance == Decimal.new("456.7")
      assert account.name == "some updated name"
    end

    test "update_account/2 with invalid data returns error changeset" do
      account = account_fixture()
      assert {:error, %Ecto.Changeset{}} = Entries.update_account(account, @invalid_attrs)
      assert account == Entries.get_account!(account.id)
    end

    test "delete_account/1 deletes the account" do
      account = account_fixture()
      assert {:ok, %Account{}} = Entries.delete_account(account)
      assert_raise Ecto.NoResultsError, fn -> Entries.get_account!(account.id) end
    end

    test "change_account/1 returns a account changeset" do
      account = account_fixture()
      assert %Ecto.Changeset{} = Entries.change_account(account)
    end
  end
end

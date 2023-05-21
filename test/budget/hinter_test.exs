defmodule Budget.HinterTest do
  use Budget.DataCase, async: true

  import Budget.TransactionsFixtures

  alias Budget.Hinter

  describe "hint_description/1" do
    test "hints description" do
      Hinter.process_descriptions([
        {"something here", "turned this"},
        {"something there", "is this"}
      ])

      assert [
               %{original: "something here", rank: 0.6666666865348816, suggestion: "turned this"},
               %{original: "something there", rank: 0.625, suggestion: "is this"}
             ] == Hinter.hint_description("something")

      assert [
               %{original: "something here", rank: 0.6875, suggestion: "turned this"},
               %{original: "something there", rank: 0.5555555820465088, suggestion: "is this"}
             ] == Hinter.hint_description("something h")
    end

    test "ignores parcels when searching" do
      Hinter.process_descriptions([
        {"something", "this should match as parcel is removed from the query"},
        {"something 3/4", "is this"}
      ])

      assert [
               %{
                 original: "something",
                 rank: 1.0,
                 suggestion: "this should match as parcel is removed from the query"
               },
               %{original: "something 3/4", rank: 0.7142857313156128, suggestion: "is this"}
             ] == Hinter.hint_description("something 3/4")
    end
  end

  describe "hint_category/2" do
    test "when nothing matches" do
      hint = Hinter.hint_category("nothing match", nil)

      refute hint
    end

    test "matches without account" do
      transaction = transaction_fixture()

      hint = Hinter.hint_category("Transaction description", nil)

      assert hint.id == transaction.originator_regular.category_id
    end

    test "matches with account" do
      transaction_fixture()
      transaction = transaction_fixture()

      hint = Hinter.hint_category("Transaction description", transaction.account_id)

      assert hint.id == transaction.originator_regular.category_id
    end
  end
end

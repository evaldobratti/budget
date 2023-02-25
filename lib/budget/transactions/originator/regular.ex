defmodule Budget.Transactions.Originator.Regular do
  use Ecto.Schema
  import Ecto.Changeset

  import Ecto.Query
  alias Budget.Transactions.Transaction
  alias Budget.Transactions.Category
  alias Budget.Transactions

  schema "originators_regular" do
    field :description, :string
    belongs_to :category, Category

    timestamps()
  end

  @behaviour Budget.Transactions.Originator

  def restore_for_recurrency(payload) do
    category =
      payload
      |> Map.get("category_id")
      |> Transactions.get_category!()

    account =
      payload
      |> Map.get("account_id")
      |> Transactions.get_account!()

    %{
      originator_regular: %__MODULE__{
        description: Map.get(payload, "description"),
        category: category,
        category_id: category.id
      },
      value: Decimal.new(Map.get(payload, "value")),
      account_id: account.id,
      account: account
    }
  end

  def get_recurrency_payload(transaction) do
    %{description: description, category_id: category_id} = transaction.originator_regular

    %{
      description: description,
      category_id: category_id,
      value: transaction.value,
      account_id: transaction.account_id,
      originator: __MODULE__
    }
  end

  def build_transactions(recurrency_params, params) do
    %Budget.Transactions.Transaction{}
    |> Map.merge(recurrency_params)
    |> Map.merge(params)
  end

  def delete(transaction_ids) do
    regular_ids =
      from(
        transaction in Transaction,
        where: transaction.id in ^transaction_ids,
        select: transaction.originator_regular_id
      )

    fn _ ->
      Ecto.Multi.new()
      |> Ecto.Multi.run(:transactions, fn _, _ -> {:ok, transaction_ids} end)
      |> Ecto.Multi.all(:originators, regular_ids)
    end
  end
end

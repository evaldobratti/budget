defmodule Budget.Entries.Originator.Regular do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.Entries.Category
  alias Budget.Entries

  schema "originators_regular" do
    field :description, :string
    belongs_to :category, Category

    timestamps()
  end

  @behaviour Budget.Entries.Originator

  def restore_for_recurrency(payload) do
    category =
      payload
      |> Map.get("category_id")
      |> Entries.get_category!()

    account =
      payload
      |> Map.get("account_id")
      |> Entries.get_account!()
      

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
    %{description: description, category_id: category_id} =
      transaction.originator_regular

    %{
      description: description,
      category_id: category_id,
      value: transaction.value,
      account_id: transaction.account_id,
      originator: __MODULE__
    }
  end

  def build_entries(recurrency_params, params) do
    %Budget.Entries.Entry{}
    |> Map.merge(recurrency_params)
    |> Map.merge(params)
  end
end

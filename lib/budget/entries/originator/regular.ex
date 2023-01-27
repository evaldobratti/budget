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

  def changeset(regular, attrs) do
    regular
    |> cast(attrs, [:description, :category_id])
    |> validate_required([:description, :category_id])
  end

  @behaviour Budget.Entries.Originator

  def restore_for_recurrency(%{"originator_regular" => regular} = payload) do
    category =
      regular
      |> Map.get("category_id")
      |> Entries.get_category!()

    account =
      payload
      |> Map.get("account_id")
      |> Entries.get_account!()
      

    %{
      originator_regular: %__MODULE__{
        description: Map.get(regular, "description"),
        category: category,
        category_id: category.id
      },
      value: Decimal.new(Map.get(payload, "value")),
      account_id: account.id,
      account: account
    }
  end

  def get_recurrency_payload(entry_changeset) do
    %{description: description, category_id: category_id} =
      get_field(entry_changeset, :originator_regular)

    %{
      originator_regular: %{
        description: description,
        category_id: category_id
      },
      value: get_field(entry_changeset, :value),
      account_id: get_field(entry_changeset, :account_id)
    }
  end
end

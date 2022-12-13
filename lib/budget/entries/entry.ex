defmodule Budget.Entries.Entry do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.Entries.Account
  alias Budget.Entries.Category
  alias Budget.Entries.RecurrencyEntry

  schema "entries" do
    field :date, :date
    field :description, :string
    field :is_carried_out, :boolean, default: false
    field :value, :decimal

    belongs_to :account, Account
    belongs_to :category, Category

    field :is_recurrency, :boolean, virtual: true
    field :recurrency_apply_forward, :boolean, virtual: true

    has_one :recurrency_entry, RecurrencyEntry

    timestamps()
  end

  @doc false
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :date,
      :description,
      :is_carried_out,
      :value,
      :account_id,
      :is_recurrency,
      :recurrency_apply_forward,
      :category_id
    ])
    |> validate_required([:date, :description, :is_carried_out, :value, :account_id, :category_id])
    |> cast_assoc(:recurrency_entry, with: &RecurrencyEntry.changeset_from_entry/2)
  end

  @doc false
  def changeset_transient(entry, attrs) do
    entry
    |> cast(attrs, [
      :date,
      :description,
      :is_carried_out,
      :value,
      :account_id,
      :is_recurrency,
      :recurrency_apply_forward,
      :category_id
    ])
    |> validate_required([:date, :description, :is_carried_out, :value, :account_id, :category_id])
    |> cast_assoc(:recurrency_entry, with: &RecurrencyEntry.changeset_from_entry_transient/2)
  end
end

defmodule Budget.Entries.RecurrencyEntry do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.Entries.Entry
  alias Budget.Entries.Recurrency

  schema "recurrency_entries" do
    field :original_date, :date
    belongs_to :recurrency, Recurrency
    belongs_to :entry, Entry

    timestamps()
  end

  def changeset_from_recurrency(recurrency_entry, attrs) do
    recurrency_entry
    |> cast(attrs, [:original_date])
    |> validate_required([:original_date])
    |> cast_assoc(:entry)
  end

  def changeset_from_entry(recurrency_entry, attrs) do
    recurrency_entry
    |> cast(attrs, [:original_date])
    |> validate_required([:original_date])
    |> cast_assoc(:recurrency)
  end

  def changeset_from_entry_transient(recurrency_entry, attrs) do
    recurrency_entry
    |> cast(attrs, [:original_date, :recurrency_id])
    |> validate_required([:original_date, :recurrency_id])
  end
end

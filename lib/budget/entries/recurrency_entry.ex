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
    |> cast(attrs, [:original_date, :recurrency_id, :entry_id])
    |> validate_required([:original_date, :entry_id])
  end

  def changeset_from_entry(recurrency_entry, attrs) do
    recurrency_entry
    |> cast(attrs, [:original_date, :recurrency_id, :entry_id])
    |> validate_required([:original_date, :recurrency_id])
  end
end

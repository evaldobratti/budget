defmodule Budget.Entries.RecurrencyEntry do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.Entries.Entry
  alias Budget.Entries.Recurrency

  schema "recurrency_entries" do
    field :original_date, :date
    field :parcel, :integer
    field :parcel_end, :integer

    belongs_to :recurrency, Recurrency
    belongs_to :entry, Entry

    timestamps()
  end

  def changeset(recurrency_entry, attrs) do
    recurrency_entry
    |> cast(attrs, [:original_date, :recurrency_id])
    |> cast_assoc(:recurrency)
  end
end

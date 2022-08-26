defmodule Budget.Entries.Recurrency do
  use Ecto.Schema
  import Ecto.Changeset

  schema "recurrencies" do
    field :date_end, :date
    field :date_start, :date
    field :description, :string
    field :frequency, :string
    field :is_forever, :boolean, default: false
    field :is_parcel, :boolean, default: false
    field :parcel_end, :integer
    field :parcel_start, :integer
    field :value, :decimal
    field :account_id, :id

    timestamps()
  end

  @doc false
  def changeset(recurrency, attrs) do
    recurrency
    |> cast(attrs, [:is_forever, :value, :frequency, :date_start, :date_end, :description, :parcel_start, :parcel_end, :is_parcel])
    |> validate_required([:is_forever, :value, :frequency, :date_start, :date_end, :description, :parcel_start, :parcel_end, :is_parcel])
  end
end

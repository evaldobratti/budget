defmodule Budget.Entries.Recurrency do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.Entries.Entry

  schema "recurrencies" do
    field :date_end, :date
    field :date_start, :date
    field :description, :string
    field :frequency, Ecto.Enum, values: [:weekly, :monthly, :yearly]
    field :is_forever, :boolean
    field :is_parcel, :boolean, default: false
    field :parcel_end, :integer
    field :parcel_start, :integer
    field :value, :decimal
    field :account_id, :id
    belongs_to :entry_origin, Entry

    timestamps()
  end

  @doc false
  def changeset(recurrency, attrs) do
    changeset = 
      recurrency
      |> cast(attrs, [:frequency, :is_parcel, :is_forever, :value, :frequency, :date_start, :date_end, :description, :parcel_start, :parcel_end, :is_parcel, :account_id, :entry_origin_id])
      |> validate_required([:date_start, :description, :value, :account_id, :is_forever, :is_parcel, :frequency])

    if get_field(changeset, :is_forever) && get_field(changeset, :is_parcel) do
      add_error(changeset, :is_forever, "Recurrency can't be infinite parcel")
    else
      if get_field(changeset, :is_forever) do
        put_change(changeset, :date_end, nil)
      else
        if get_field(changeset, :is_parcel) do
          validate_required(changeset, [:parcel_start, :parcel_end])
        else 
          validate_required(changeset, :date_end)
        end
      end
    end
  end

  def entries(%__MODULE__{} = recurrency, until_date) do
    first_end = 
      [recurrency.date_end, until_date]
      |> Enum.sort(&Timex.before?/2)
      |> Enum.at(0)

    dates = dates(recurrency.frequency, recurrency.date_start, first_end)

    Enum.map(dates, & %{
      date: &1,
      description: recurrency.description,
      value: recurrency.value
    })
  end

  def dates(frequency, current_date, until_date) do
    if Timex.before?(current_date, until_date) or Timex.equal?(current_date, until_date) do
      next = recurrency_shift(frequency, current_date)
      [current_date] ++ dates(frequency, next, until_date)
    else
      []
    end
  end

  def recurrency_shift(:monthly, date) do
    Timex.shift(date, months: 1)
  end

  def recurrency_shift(:weekly, date) do
    Timex.shift(date, weeks: 1)
  end


end

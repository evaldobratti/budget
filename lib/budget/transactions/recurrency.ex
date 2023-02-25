defmodule Budget.Transactions.Recurrency do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.Transactions.RecurrencyTransaction

  schema "recurrencies" do
    field :date_end, :date
    field :date_start, :date
    field :frequency, Ecto.Enum, values: [:weekly, :monthly, :yearly], default: :monthly
    field :is_forever, :boolean
    field :is_parcel, :boolean, default: false
    field :parcel_end, :integer
    field :parcel_start, :integer
    field :transaction_payload, :map

    has_many :recurrency_transactions, RecurrencyTransaction

    timestamps()
  end

  @doc false
  def changeset(recurrency, attrs) do
    changeset =
      recurrency
      |> cast(attrs, [
        :frequency,
        :is_parcel,
        :is_forever,
        :frequency,
        :date_start,
        :date_end,
        :parcel_start,
        :parcel_end,
        :is_parcel,
      ])
      |> validate_required([
        :is_parcel,
        :frequency
      ])

    if get_field(changeset, :is_forever) && get_field(changeset, :is_parcel) do
      # TODO allow this to happen
      add_error(changeset, :is_forever, "Recurrency can't be infinite parcel")
    else
      if Ecto.get_meta(changeset.data, :state) == :loaded do
        changeset
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
  end

  def transactions(%__MODULE__{} = recurrency, until_date) do
    first_end =
      cond do
        recurrency.is_forever -> [recurrency.date_end, until_date]
        recurrency.is_parcel -> [recurrency.date_end, until_date, parcel_end_date(recurrency)]
        true -> [recurrency.date_end, until_date]
      end
      |> Enum.filter(& &1)
      |> Enum.sort(&Timex.before?/2)
      |> Enum.at(0)

    dates = dates(recurrency.frequency, 0, recurrency.date_start, first_end)

    originator = 
      recurrency.transaction_payload
      |> Map.values()
      |> Enum.random()
      |> Map.get("originator")
      |> String.to_existing_atom()

    payloads =
      recurrency.transaction_payload
      |> Enum.map(fn {date, payload} ->
        {Date.from_iso8601!(date), originator.restore_for_recurrency(payload)}
      end)
      |> Enum.into(%{})

    dates
    |> Enum.with_index()
    |> Enum.map(fn {date, ix} ->
      recurrency_transaction =
        if recurrency.is_parcel do
          %RecurrencyTransaction{
            original_date: date,
            recurrency_id: recurrency.id,
            recurrency: recurrency,
            parcel: ix + recurrency.parcel_start,
            parcel_end: recurrency.parcel_end
          }
        else
          %RecurrencyTransaction{
            original_date: date,
            recurrency_id: recurrency.id,
            recurrency: recurrency
          }
        end

      params = payload_at_date(payloads, date)

      originator.build_transactions(%{
        id: "recurrency-#{recurrency.id}-#{Date.to_iso8601(date)}",
        date: date,
        is_recurrency: true,
        recurrency_transaction: recurrency_transaction,
        position: Decimal.new(1)
      }, params)
    end)
    |> List.flatten()
    |> Enum.filter(
      &(!Enum.any?(recurrency.recurrency_transactions, fn re ->
          re.original_date == &1.recurrency_transaction.original_date
        end))
    )
  end

  defp payload_at_date(payloads, at_date) do
    payloads
    |> Enum.filter(fn {date, _payload} ->
      Timex.equal?(date, at_date) or Timex.before?(date, at_date)
    end)
    |> Enum.min_by(
      fn {date, _payload} ->
        date
      end,
      &Timex.after?/2
    )
    |> elem(1)
  end

  def dates(frequency, ix_offset, initial_date, until_date) do
    current_date = Timex.shift(initial_date, [{recurrency_shift(frequency), ix_offset}])

    if Timex.before?(current_date, until_date) or Timex.equal?(current_date, until_date) do
      [current_date] ++ dates(frequency, ix_offset + 1, initial_date, until_date)
    else
      []
    end
  end

  def recurrency_shift(:monthly), do: :months
  def recurrency_shift(:weekly), do: :weeks
  def recurrency_shift(:yearly), do: :years

  defp parcel_end_date(%__MODULE__{} = recurrency) do
    parcel_end_date(recurrency, 0, recurrency.date_start, recurrency.parcel_start)
  end

  def parcel_end_date(recurrency, ix_offset, initial_date, current_parcel) do
    current_date =
      Timex.shift(initial_date, [{recurrency_shift(recurrency.frequency), ix_offset}])

    if current_parcel == recurrency.parcel_end do
      current_date
    else
      parcel_end_date(
        recurrency,
        ix_offset + 1,
        initial_date,
        current_parcel + 1
      )
    end
  end
end

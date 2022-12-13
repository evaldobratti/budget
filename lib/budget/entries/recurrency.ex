defmodule Budget.Entries.Recurrency do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.Entries.Account
  alias Budget.Entries.Category
  alias Budget.Entries.Entry
  alias Budget.Entries.RecurrencyEntry

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

    belongs_to :account, Account
    belongs_to :category, Category

    has_many :recurrency_entries, RecurrencyEntry

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
        :value,
        :frequency,
        :date_start,
        :date_end,
        :description,
        :parcel_start,
        :parcel_end,
        :is_parcel,
        :account_id,
        :category_id
      ])
      |> validate_required([
        :date_start,
        :description,
        :value,
        :account_id,
        :is_parcel,
        :frequency,
        :category_id
      ])
      |> cast_assoc(:recurrency_entries, with: &RecurrencyEntry.changeset_from_recurrency/2)

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

  def entries(%__MODULE__{} = recurrency, until_date) do
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

    dates
    |> Enum.with_index()
    |> Enum.map(fn {date, ix} ->
      complement =
        if recurrency.is_parcel do
          " (#{ix + recurrency.parcel_start}/#{recurrency.parcel_end})"
        else
          ""
        end

      %Entry{
        id: "recurrency-#{recurrency.id}-#{Date.to_iso8601(date)}",
        date: date,
        description: recurrency.description <> complement,
        account: recurrency.account,
        account_id: recurrency.account_id,
        category_id: recurrency.category_id,
        value: recurrency.value,
        is_recurrency: true,
        recurrency_entry: %RecurrencyEntry{
          original_date: date,
          recurrency_id: recurrency.id,
          recurrency: recurrency
        }
      }
    end)
    |> Enum.filter(
      &(!Enum.any?(recurrency.recurrency_entries, fn re ->
          re.original_date == &1.recurrency_entry.original_date
        end))
    )
  end

  def dates(frequency, ix_offset, initial_date, until_date) do
    current_date = Timex.shift(initial_date, [{recurrency_shift(frequency), ix_offset}])

    if Timex.before?(current_date, until_date) or Timex.equal?(current_date, until_date) do
      [current_date] ++ dates(frequency, ix_offset + 1, initial_date, until_date)
    else
      []
    end
  end

  def recurrency_shift(:monthly) do
    :months
  end

  def recurrency_shift(:weekly) do
    :weeks
  end

  defp parcel_end_date(%__MODULE__{} = recurrency) do
    parcel_end_date(recurrency, 0, recurrency.date_start, recurrency.parcel_start)
  end

  def parcel_end_date(recurrency, ix_offset, initial_date, current_parcel) do
    current_date = Timex.shift(initial_date, [{recurrency_shift(recurrency.frequency), ix_offset}])

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

  def apply_any_description_update(entry_changeset) do
    case apply_action(entry_changeset, :insert) do
      {
        :ok,
        %{
          recurrency_entry: %{
            recurrency: %{
              is_parcel: true,
              parcel_start: parcel_start,
              parcel_end: parcel_end
            }
          }
        }
      } ->
        update_change(entry_changeset, :description, &(&1 <> " (#{parcel_start}/#{parcel_end})"))

      _ ->
        entry_changeset
    end
  end
end

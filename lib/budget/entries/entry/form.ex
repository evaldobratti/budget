defmodule Budget.Entries.Entry.Form do
  use Ecto.Schema

  import Ecto.Changeset

  alias Budget.Entries
  alias Budget.Entries.Originator.Transfer
  alias Budget.Entries.Entry
  alias Budget.Entries.Originator.Regular
  alias Budget.Entries.Recurrency
  alias Budget.Entries.RecurrencyEntry

  embedded_schema do
    field :date, :date
    field :is_carried_out, :boolean, default: false
    field :value, :decimal
    field :account_id, :integer

    field :originator, :string
    field :is_recurrency, :boolean

    field :keep_adding, :boolean

    embeds_one :regular, Regular do
      field :category_id, :integer
      field :description
    end

    embeds_one :transfer, Transfer do
      field :other_account_id, :integer
    end

    embeds_one :recurrency, Recurrency do
      field :apply_forward, :boolean
      field :frequency, Ecto.Enum, values: [:weekly, :monthly, :yearly]
      field :is_parcel, :boolean
      field :is_forever, :boolean
      field :date_end, :date
      field :parcel_start, :integer
      field :parcel_end, :integer
    end
  end

  def insert_changeset(params) do
    originator = Map.get(params, :originator, "regular")

    %__MODULE__{}
    |> cast(params, [
      :date,
      :is_carried_out,
      :value,
      :account_id,
      :originator,
      :is_recurrency,
      :keep_adding
    ])
    |> validate_required([:date, :value, :account_id, :originator])
    |> cast_embed(:regular, with: &changeset_regular/2, required: originator == "regular")
    |> cast_embed(:transfer, with: &changeset_transfer/2, required: originator == "transfer")
    |> cast_embed(:recurrency, with: &changeset_recurrency/2)
  end

  def changeset_regular(regular, params) do
    regular
    |> cast(params, [
      :category_id,
      :description
    ])
    |> validate_required([
      :category_id,
      :description
    ])
  end

  def changeset_transfer(transfer, params) do
    transfer
    |> cast(params, [
      :other_account_id
    ])
    |> validate_required([
      :other_account_id
    ])
  end

  def changeset_recurrency(recurrency, params) do
    changeset =
      recurrency
      |> cast(params, [
        :apply_forward,
        :frequency,
        :is_parcel,
        :is_forever,
        :date_end,
        :parcel_start,
        :parcel_end
      ])
      |> validate_required([
        :is_forever,
        :frequency,
        :is_parcel
      ])

    if get_field(changeset, :is_forever) && get_field(changeset, :is_parcel) do
      add_error(changeset, :is_forever, "Recurrency can't be infinite parcel")
    else
      if get_field(changeset, :is_forever) do
        changeset
        |> put_change(:parcel_start, nil)
        |> put_change(:parcel_end, nil)
      else
        if get_field(changeset, :is_parcel) do
          changeset
          |> validate_required([:parcel_start, :parcel_end])
        else
          changeset
          |> validate_required(:date_end)
        end
      end
    end
  end

  def apply_insert(%Ecto.Changeset{valid?: true, changes: %{recurrency: _recurrency}} = changeset) do
    recurrency = get_change(changeset, :recurrency)

    changeset
    |> put_embed(:recurrency, nil)
    |> apply_insert()
    |> flat_insert_transactions(changeset)
    |> case do
      {:ok, transactions} ->
        {:ok, _recurrency} = 
          %Recurrency{}
          |> change(%{
            date_start: get_field(changeset, :date),
            date_end: get_field(recurrency, :date_end),
            frequency: get_field(recurrency, :frequency),
            is_forever: get_field(recurrency, :is_forever),
            is_parcel: get_field(recurrency, :is_parcel),
            parcel_start: get_field(recurrency, :parcel_start),
            parcel_end: get_field(recurrency, :parcel_end),
            entry_payload:
              case get_change(changeset, :originator) do
                "regular" -> Regular.get_recurrency_payload(Enum.at(transactions, 0))
                "transfer" -> Transfer.get_recurrency_payload(Enum.at(transactions, 0))
              end
          })
          |> put_assoc(
            :recurrency_entries,
            Enum.map(
              transactions,
              &%RecurrencyEntry{
                original_date: get_field(changeset, :date),
                entry_id: &1.id,
                parcel: get_field(recurrency, :parcel_start),
                parcel_end: get_field(recurrency, :parcel_end)
              }
            )
          )
          |> Budget.Repo.insert()

        refreshed = Entries.get_entry!(Enum.at(transactions, 0).id)

        {:ok, refreshed}

      error ->
        error
    end
  end

  def apply_insert(%Ecto.Changeset{valid?: true, changes: %{originator: "regular"}} = changeset) do
    regular = get_change(changeset, :regular)

    originator = %Regular{
      category_id: get_change(regular, :category_id),
      description: get_change(regular, :description)
    }

    %Entry{}
    |> change(%{
      date: get_change(changeset, :date),
      value: get_change(changeset, :value),
      account_id: get_change(changeset, :account_id)
    })
    |> put_assoc(:originator_regular, originator)
    |> Budget.Repo.insert()
  end

  def apply_insert(%Ecto.Changeset{valid?: true, changes: %{originator: "transfer"}} = changeset) do
    transfer = get_change(changeset, :transfer)

    originator =
      %Transfer{}
      |> change()
      |> put_assoc(:counter_part, %Entry{
        date: get_change(changeset, :date),
        value: get_change(changeset, :value) |> Decimal.negate(),
        account_id: get_change(transfer, :other_account_id)
      })

    %Entry{}
    |> change(%{
      date: get_change(changeset, :date),
      value: get_change(changeset, :value),
      account_id: get_change(changeset, :account_id)
    })
    |> put_assoc(:originator_transfer_part, originator)
    |> Budget.Repo.insert()
  end

  defp flat_insert_transactions({:ok, transaction}, %Ecto.Changeset{
         changes: %{originator: "regular"}
       }) do
    {:ok, [transaction]}
  end

  defp flat_insert_transactions({:ok, transaction}, %Ecto.Changeset{
         changes: %{originator: "transfer"}
       }) do
    {:ok, [transaction, transaction.originator_transfer_part.counter_part]}
  end

  defp flat_insert_transactions(error, _changeset), do: error
end

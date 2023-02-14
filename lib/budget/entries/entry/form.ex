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
    field(:date, :date)
    field(:is_carried_out, :boolean, default: false)
    field(:value, :decimal)
    field(:account_id, :integer)
    field(:position, :decimal)

    field(:originator, :string)
    field(:is_recurrency, :boolean)

    field(:keep_adding, :boolean, default: true)

    field(:apply_forward, :boolean)

    embeds_one :regular, RegularForm do
      field(:category_id, :integer)
      field(:description)
    end

    embeds_one :transfer, TransferForm do
      field(:other_account_id, :integer)
    end

    embeds_one :recurrency, RecurrencyForm do
      field(:frequency, Ecto.Enum, values: [:weekly, :monthly, :yearly], default: :monthly)
      field(:is_parcel, :boolean, default: false)
      field(:is_forever, :boolean)
      field(:date_end, :date)
      field(:parcel_start, :integer)
      field(:parcel_end, :integer)
    end
  end

  def insert_changeset(params) do
    changeset = 
      %__MODULE__{}
      |> cast(params, [
        :date,
        :is_carried_out,
        :value,
        :account_id,
        :position,
        :originator,
        :is_recurrency,
        :keep_adding,
        :apply_forward
      ])
      |> validate_required([:date, :value, :account_id, :originator])

    originator = get_change(changeset, :originator) || "regular"

    changeset
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
        :frequency,
        :is_parcel,
        :is_forever,
        :date_end,
        :parcel_start,
        :parcel_end
      ])
      |> validate_required([
        :is_forever,
        :frequency
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

    Ecto.Multi.new()
    |> Ecto.Multi.run(:transaction, fn _repo, _changes ->
      changeset
      |> put_embed(:recurrency, nil)
      |> apply_insert()
    end)
    |> Ecto.Multi.run(:recurrency, fn _repo, %{transaction: transaction} ->
      transactions = flat_insert_transactions(transaction, changeset)

      %Recurrency{}
      |> change(%{
        date_start: get_field(changeset, :date),
        date_end: get_field(recurrency, :date_end),
        frequency: get_field(recurrency, :frequency),
        is_forever: get_field(recurrency, :is_forever),
        is_parcel: get_field(recurrency, :is_parcel),
        parcel_start: get_field(recurrency, :parcel_start),
        parcel_end: get_field(recurrency, :parcel_end),
        entry_payload: %{
          get_field(changeset, :date) =>
            case get_change(changeset, :originator) do
              "regular" -> Regular.get_recurrency_payload(Enum.at(transactions, 0))
              "transfer" -> Transfer.get_recurrency_payload(Enum.at(transactions, 0))
            end
        }
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
    end)
    |> Ecto.Multi.run(:result, fn _repo, %{transaction: transaction} ->
      refreshed = Entries.get_entry!(transaction.id)

      {:ok, refreshed}
    end)
    |> Budget.Repo.transaction()
    |> case do
      {:ok, %{result: result}} ->
        {:ok, result}

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
      account_id: get_change(changeset, :account_id),
      position:
        get_change(changeset, :position) ||
          Entries.next_position_for_date(get_change(changeset, :date))
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
        account_id: get_change(transfer, :other_account_id),
        position:
          get_change(changeset, :position) ||
            Entries.next_position_for_date(get_change(changeset, :date))
      })

    %Entry{}
    |> change(%{
      date: get_change(changeset, :date),
      value: get_change(changeset, :value),
      account_id: get_change(changeset, :account_id),
      position:
        get_change(changeset, :position) ||
          Entries.next_position_for_date(get_change(changeset, :date))
    })
    |> put_assoc(:originator_transfer_part, originator)
    |> Budget.Repo.insert()
  end

  def apply_insert(%Ecto.Changeset{valid?: false} = changeset) do
    {:error, Map.put(changeset, :action, :insert)}
  end

  def apply_insert(params) when is_map(params) do
    params
    |> insert_changeset()
    |> apply_insert()
  end

  defp flat_insert_transactions(transaction, %Ecto.Changeset{
         changes: %{originator: "regular"}
       }) do
    [transaction]
  end

  defp flat_insert_transactions(transaction, %Ecto.Changeset{
         changes: %{originator: "transfer"}
       }) do
    [transaction, transaction.originator_transfer_part.counter_part]
  end

  def decorate(%Entry{} = transaction) do
    base = %__MODULE__{
      id: transaction.id,
      date: transaction.date,
      is_carried_out: transaction.is_carried_out,
      account_id: transaction.account_id,
      value: transaction.value,
      keep_adding: false,
      apply_forward: false,
      position: transaction.position
    }

    regular_data =
      if (Ecto.assoc_loaded?(transaction.originator_regular) && transaction.originator_regular) ||
           transaction.originator_regular_id do
        %__MODULE__.RegularForm{
          description: transaction.originator_regular.description,
          category_id: transaction.originator_regular.category_id
        }
      else
        nil
      end

    transfer_data =
      if transaction.originator_transfer_part_id do
        %__MODULE__.TransferForm{
          other_account_id: transaction.originator_transfer_part.counter_part.account_id
        }
      else
        if transaction.originator_transfer_counter_part_id do
          %__MODULE__.TransferForm{
            other_account_id: transaction.originator_transfer_counter_part.part.account_id
          }
        else
          nil
        end
      end

    originator = if regular_data, do: "regular", else: "transfer"

    %{
      base
      | originator: originator,
        regular: regular_data,
        transfer: transfer_data,
        is_recurrency: (
          transaction.recurrency_entry &&
          transaction.recurrency_entry.__struct__ == Budget.Entries.RecurrencyEntry
        )
    }
  end

  def update_changeset(form, params) do
    form
    |> cast(params, [
      :date,
      :account_id,
      :is_carried_out,
      :position,
      :value,
      :apply_forward
    ])
    |> validate_required([
      :date,
      :account_id,
      :is_carried_out,
      :value
    ])
    |> cast_embed(:regular, with: &changeset_regular/2)
    |> cast_embed(:transfer, with: &changeset_transfer/2)
  end

  def apply_update(
        %Ecto.Changeset{valid?: true} = changeset,
        %{id: "recurrency" <> _} = transaction
      ) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:inserted, fn _repo, _changes ->
      transaction
      |> Map.put(:id, nil)
      |> Budget.Repo.insert()
    end)
    |> Ecto.Multi.run(:result, fn _repo, %{inserted: inserted} ->
      apply_update(changeset, inserted)
    end)
    |> Budget.Repo.transaction()
    |> case do
      {:ok, %{result: result}} ->
        {:ok, result}

      error ->
        error
    end
  end

  def apply_update(
        %Ecto.Changeset{valid?: true, changes: %{apply_forward: true}} = changeset,
        transaction
      ) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:transaction, fn _repo, _changes ->
      changeset
      |> change(apply_forward: false)
      |> apply_update(transaction)
    end)
    |> Ecto.Multi.run(:recurrency, fn _repo, %{transaction: transaction} ->
      transaction.recurrency_entry.recurrency
      |> change(
        entry_payload:
          Map.put(
            transaction.recurrency_entry.recurrency.entry_payload,
            transaction.recurrency_entry.original_date |> Date.to_iso8601(),
            case get_field(changeset, :originator) do
              "regular" -> Regular.get_recurrency_payload(transaction)
              "transfer" -> Transfer.get_recurrency_payload(transaction)
            end
          )
      )
      |> Budget.Repo.update()
    end)
    |> Ecto.Multi.run(:result, fn _repo, %{transaction: transaction} ->
      {:ok, Entries.get_entry!(transaction.id)}
    end)
    |> Budget.Repo.transaction()
    |> case do
      {:ok, %{result: result}} ->
        {:ok, result}

      error ->
        error
    end
  end

  def apply_update(
        %Ecto.Changeset{valid?: true, data: %{originator: "regular"}} = changeset,
        transaction
      ) do
    regular = get_field(changeset, :regular)

    transaction
    |> change(%{
      date: get_field(changeset, :date),
      account_id: get_field(changeset, :account_id),
      value: get_field(changeset, :value),
      position: get_field(changeset, :position)
    })
    |> put_assoc(
      :originator_regular,
      transaction.originator_regular
      |> change(
        category_id: regular.category_id,
        description: regular.description
      )
    )
    |> Budget.Repo.update()
  end

  def apply_update(
        %Ecto.Changeset{valid?: true, data: %{originator: "transfer"}} = changeset,
        transaction
      ) do
    transfer = get_field(changeset, :transfer)

    changeset =
      transaction
      |> change(%{
        date: get_field(changeset, :date),
        account_id: get_field(changeset, :account_id),
        value: get_field(changeset, :value),
        position: get_field(changeset, :position)
      })

    {entry_transfer_field, transfer_field} =
      if transaction.originator_transfer_part_id do
        {:originator_transfer_part, :counter_part}
      else
        {:originator_transfer_counter_part, :part}
      end

    current_counter_part =
      transaction
      |> Map.get(entry_transfer_field)
      |> Map.get(transfer_field)

    changeset
    |> put_assoc(
      entry_transfer_field,
      transaction
      |> Map.get(entry_transfer_field)
      |> change()
      |> put_assoc(
        transfer_field,
        transaction
        |> Map.get(entry_transfer_field)
        |> Map.get(transfer_field)
        |> change(
          date: get_field(changeset, :date),
          account_id:
            Map.get(transfer || %{}, :other_account_id, current_counter_part.account_id),
          value: get_field(changeset, :value) |> Decimal.negate()
        )
      )
    )
    |> Budget.Repo.update()
  end

  def apply_update(
        %Ecto.Changeset{valid?: false} = changeset,
        _transaction
      ) do
    {:error, Map.put(changeset, :action, :update)}
  end

  def apply_update(transaction, params) when is_map(params) do
    transaction
    |> decorate()
    |> update_changeset(params)
    |> apply_update(transaction)
  end
end

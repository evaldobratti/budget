defmodule Budget.Transactions.Transaction.Form do
  use Ecto.Schema

  import Ecto.Changeset

  alias Budget.Hinter
  alias Ecto.Changeset

  alias Budget.Transactions
  alias Budget.Transactions.Originator.Transfer
  alias Budget.Transactions.Transaction
  alias Budget.Transactions.Originator.Regular
  alias Budget.Transactions.Recurrency
  alias Budget.Transactions.RecurrencyTransaction

  embedded_schema do
    field(:date, :date)
    field(:value, :decimal)
    field(:value_raw, :string)
    field(:recurrency_description, :string)
    field(:account_id, :integer)
    field(:position, :decimal)

    field(:originator, :string)
    field(:is_recurrency, :boolean)

    field(:paid, :boolean, default: true)
    field(:apply_forward, :boolean)

    field :profile_id, :integer

    embeds_one :regular, RegularForm do
      field(:category_id, :integer)
      field(:description)
      field(:original_description)
    end

    embeds_one :transfer, TransferForm do
      field(:other_account_id, :integer)
    end

    embeds_one :recurrency, RecurrencyForm do
      field(:type, Ecto.Enum, values: [:until_date, :forever, :parcel])
      field(:frequency, Ecto.Enum, values: [:weekly, :monthly, :yearly], default: :monthly)
      field(:date_end, :date)
      field(:parcel_start, :integer)
      field(:parcel_end, :integer)
    end
  end

  def insert_changeset(params) do
    params = parse_recurrency_shortcut(params)

    changeset =
      %__MODULE__{}
      |> cast(params, [
        :date,
        :value,
        :account_id,
        :position,
        :originator,
        :is_recurrency,
        :apply_forward,
        :paid,
        :recurrency_description,
        :value_raw
      ])
      |> validate_required([:date, :value, :account_id, :originator, :paid])
      |> Budget.Repo.add_profile_id()

    originator = get_change(changeset, :originator) || "regular"

    case originator do
      "regular" ->
        cast_embed(changeset, :regular,
          with: &changeset_regular/2,
          required: originator == "regular"
        )

      "transfer" ->
        cast_embed(changeset, :transfer,
          with: fn transfer, params -> changeset_transfer(transfer, params, changeset) end,
          required: originator == "transfer"
        )
    end
    |> cast_embed(:recurrency, with: &changeset_recurrency/2)
  end

  def parse_recurrency_shortcut(params) do
    regex = ~r/(?<value>-?\d+(?:[,.]\d+)?)\s*(?<operation>[\*\/])\s*(?<parcels>\d+)/

    string_keys =
      Map.keys(params)
      |> Enum.map(&is_binary/1)
      |> Enum.all?(& &1 == true)

    k = fn value ->
      if string_keys do
        value
      else
        String.to_existing_atom(value)
      end
    end

    value_raw = Map.get(params, k.("value_raw"), Map.get(params, k.("value"), "")) |> to_string

    case Regex.named_captures(regex, to_string(value_raw)) do
      %{"value" => value_string, "operation" => operation, "parcels" => parcels_string} ->
        {:ok, value } = Decimal.cast(value_string |> String.replace(",", "."))
        {parcels, _} = Integer.parse(parcels_string)

        value =
          if operation == "/" do
             Decimal.div(value, parcels)
          else
            value
          end

        params
        |> Map.put(k.("recurrency"), %{
          k.("type") => "parcel",
          k.("frequency") => "monthly",
          k.("parcel_start") => "1",
          k.("parcel_end") =>  parcels_string,
        })
        |> Map.put(k.("value"), value |> Decimal.to_string())
        |> Map.put(k.("recurrency_description"), "A recurrency with #{parcels} parcels with value #{value} will be created")

      nil ->
        params
        |> Map.put(k.("value"), String.replace(value_raw, ",", "."))
    end
  end

  def changeset_regular(regular, params) do
    regular
    |> cast(params, [
      :category_id,
      :description,
      :original_description
    ])
    |> validate_required([
      :category_id,
      :description
    ])
  end

  def changeset_transfer(transfer, params, transaction_changeset) do
    changeset =
      transfer
      |> cast(params, [
        :other_account_id
      ])
      |> validate_required([
        :other_account_id
      ])

    account_id1 = get_field(transaction_changeset, :account_id)
    account_id2 = get_field(changeset, :other_account_id)

    if account_id1 && account_id1 == account_id2 do
      add_error(changeset, :other_account_id, "can't be the same as the origin")
    else
      changeset
    end
  end

  def changeset_recurrency(recurrency, params) do
    changeset =
      recurrency
      |> cast(params, [
        :frequency,
        :type,
        :date_end,
        :parcel_start,
        :parcel_end
      ])
      |> validate_required([
        :type,
        :frequency
      ])

    case get_field(changeset, :type) do
      :forever -> put_change(changeset, :date_end, nil)
      :parcel -> validate_required(changeset, [:parcel_start, :parcel_end])
      :until_date -> validate_required(changeset, :date_end)
      nil -> changeset
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
        type: get_field(recurrency, :type),
        parcel_start: get_field(recurrency, :parcel_start),
        parcel_end: get_field(recurrency, :parcel_end),
        transaction_payload: %{
          get_field(changeset, :date) =>
            case get_change(changeset, :originator) do
              "regular" -> Regular.get_recurrency_payload(Enum.at(transactions, 0))
              "transfer" -> Transfer.get_recurrency_payload(Enum.at(transactions, 0))
            end
        }
      })
      |> put_assoc(
        :recurrency_transactions,
        Enum.map(
          transactions,
          &(%RecurrencyTransaction{
              original_date: get_field(changeset, :date),
              transaction_id: &1.id,
              parcel: get_field(recurrency, :parcel_start),
              parcel_end: get_field(recurrency, :parcel_end)
            }
            |> Budget.Repo.add_profile_id())
        )
      )
      |> Budget.Repo.add_profile_id()
      |> Budget.Repo.insert()
    end)
    |> Ecto.Multi.run(:result, fn _repo, %{transaction: transaction} ->
      refreshed = Transactions.get_transaction!(transaction.id)

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

    originator =
      %Regular{
        category_id: get_change(regular, :category_id),
        description: get_change(regular, :description)
      }
      |> Budget.Repo.add_profile_id()

    Hinter.check(get_change(regular, :description), get_change(regular, :original_description))

    %Transaction{}
    |> change(%{
      date: get_change(changeset, :date),
      value: get_change(changeset, :value),
      account_id: get_change(changeset, :account_id),
      paid: get_change(changeset, :paid, true),
      position:
        get_change(changeset, :position) ||
          Transactions.next_position_for_date(get_change(changeset, :date))
    })
    |> put_assoc(:originator_regular, originator)
    |> Budget.Repo.add_profile_id()
    |> Budget.Repo.insert()
  end

  def apply_insert(%Ecto.Changeset{valid?: true, changes: %{originator: "transfer"}} = changeset) do
    transfer = get_change(changeset, :transfer)

    originator =
      %Transfer{}
      |> change()
      |> Budget.Repo.add_profile_id()
      |> put_assoc(
        :counter_part,
        %Transaction{
          date: get_change(changeset, :date),
          value: get_change(changeset, :value) |> Decimal.negate(),
          account_id: get_change(transfer, :other_account_id),
          paid: get_change(changeset, :paid, true),
          position:
            get_change(changeset, :position) ||
              Transactions.next_position_for_date(get_change(changeset, :date))
        }
        |> Budget.Repo.add_profile_id()
      )
      |> Budget.Repo.add_profile_id()

    %Transaction{}
    |> change(%{
      date: get_change(changeset, :date),
      value: get_change(changeset, :value),
      account_id: get_change(changeset, :account_id),
      paid: get_change(changeset, :paid, true),
      position:
        get_change(changeset, :position) ||
          Transactions.next_position_for_date(get_change(changeset, :date))
    })
    |> Budget.Repo.add_profile_id()
    |> put_assoc(:originator_transfer_part, originator)
    |> Budget.Repo.insert()
  end

  def apply_insert(%Ecto.Changeset{valid?: false} = changeset) do
    {:error, Map.put(changeset, :action, :insert)}
  end

  def apply_insert(params) when is_map(params) do
    params
    |> insert_changeset()
    |> Budget.Repo.add_profile_id()
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

  def decorate(%Transaction{} = transaction) do
    base = %__MODULE__{
      id: transaction.id,
      date: transaction.date,
      paid: transaction.paid,
      account_id: transaction.account_id,
      value: transaction.value,
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
      cond do
        is_struct(transaction.originator_transfer_part, Transfer) ->
          %__MODULE__.TransferForm{
            other_account_id: transaction.originator_transfer_part.counter_part.account_id
          }

        is_struct(transaction.originator_transfer_counter_part, Transfer) ->
          %__MODULE__.TransferForm{
            other_account_id: transaction.originator_transfer_counter_part.part.account_id
          }

        true ->
          nil
      end

    originator = if regular_data, do: "regular", else: "transfer"

    %{
      base
      | originator: originator,
        regular: regular_data,
        transfer: transfer_data,
        is_recurrency:
          transaction.recurrency_transaction &&
            Ecto.assoc_loaded?(transaction.recurrency_transaction)
    }
  end

  def update_changeset(form, params) do
    changeset =
      form
      |> cast(params, [
        :date,
        :account_id,
        :paid,
        :position,
        :value,
        :apply_forward
      ])
      |> validate_required([
        :date,
        :account_id,
        :paid,
        :value
      ])

    changeset
    |> cast_embed(:regular, with: &changeset_regular/2)
    |> cast_embed(:transfer,
      with: fn transfer, params -> changeset_transfer(transfer, params, changeset) end
    )
  end

  def apply_update(
        %Ecto.Changeset{valid?: true} = changeset,
        %{id: "recurrency" <> _} = transaction
      ) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:inserted, fn _repo, _changes ->
      transaction
      |> Map.put(:id, nil)
      |> Budget.Repo.add_profile_id()
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
      |> Budget.Repo.add_profile_id()
      |> apply_update(transaction)
    end)
    |> Ecto.Multi.run(:recurrency, fn _repo, %{transaction: transaction} ->
      transaction.recurrency_transaction.recurrency
      |> change(
        transaction_payload:
          Map.put(
            transaction.recurrency_transaction.recurrency.transaction_payload,
            transaction.recurrency_transaction.original_date |> Date.to_iso8601(),
            case get_field(changeset, :originator) do
              "regular" -> Regular.get_recurrency_payload(transaction)
              "transfer" -> Transfer.get_recurrency_payload(transaction)
            end
          )
      )
      |> Budget.Repo.update()
    end)
    |> Ecto.Multi.run(:result, fn _repo, %{transaction: transaction} ->
      {:ok, Transactions.get_transaction!(transaction.id)}
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
      position: get_field(changeset, :position),
      paid: get_field(changeset, :paid, true)
    })
    |> put_assoc(
      :originator_regular,
      transaction.originator_regular
      |> change(
        category_id: regular.category_id,
        description: regular.description
      )
    )
    |> adjust_position
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
        position: get_field(changeset, :position),
        paid: get_field(changeset, :paid, true)
      })
      |> adjust_position

    {transaction_transfer_field, transfer_field} =
      if transaction.originator_transfer_part_id do
        {:originator_transfer_part, :counter_part}
      else
        {:originator_transfer_counter_part, :part}
      end

    current_counter_part =
      transaction
      |> Map.get(transaction_transfer_field)
      |> Map.get(transfer_field)

    changeset
    |> put_assoc(
      transaction_transfer_field,
      transaction
      |> Map.get(transaction_transfer_field)
      |> change()
      |> put_assoc(
        transfer_field,
        transaction
        |> Map.get(transaction_transfer_field)
        |> Map.get(transfer_field)
        |> change(
          date: get_field(changeset, :date),
          account_id:
            Map.get(transfer || %{}, :other_account_id, current_counter_part.account_id),
          value: get_field(changeset, :value) |> Decimal.negate(),
          paid: get_field(changeset, :paid, true)
        )
        |> adjust_position
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

  defp adjust_position(%Changeset{valid?: true, changes: %{date: date} = changes} = changeset)
       when not is_map_key(changes, :position) do
    changeset
    |> put_change(:position, Transactions.next_position_for_date(date))
  end

  defp adjust_position(changeset) do
    changeset
  end
end

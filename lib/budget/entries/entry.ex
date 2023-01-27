defmodule Budget.Entries.Entry do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Budget.Entries.Recurrency
  alias Ecto.Changeset
  alias Budget.Entries.Account
  alias Budget.Entries.RecurrencyEntry
  alias Budget.Entries.Originator.Transfer
  alias Budget.Entries.Originator.Regular

  schema "entries" do
    field :date, :date
    field :is_carried_out, :boolean, default: false
    field :value, :decimal
    field :position, :decimal

    belongs_to :account, Account

    belongs_to :originator_regular, Regular, on_replace: :update
    belongs_to :originator_transfer_part, Transfer
    belongs_to :originator_transfer_counter_part, Transfer

    field :originator_transfer, :map, virtual: true
    field :is_recurrency, :boolean, virtual: true
    field :is_transfer, :boolean, virtual: true
    field :recurrency_apply_forward, :boolean, virtual: true

    has_one :recurrency_entry, RecurrencyEntry

    timestamps()
  end

  @doc false
  def changeset(
        entry,
        attrs
      ) do
    entry
    |> cast(attrs, [
      :date,
      :is_carried_out,
      :value,
      :account_id,
      :is_recurrency,
      :recurrency_apply_forward,
      :position,
      :is_transfer,
      :originator_transfer
    ])
    |> validate_required([:date, :is_carried_out, :value, :account_id])
    |> cast_assoc(:recurrency_entry)
    |> cast_assoc(:originator_regular)
    |> validate_originator()
    |> put_position()
    |> update_transfer()
    |> put_initial_recurrency_payload()
    |> put_updated_recurrency_payload()
  end

  defp put_initial_recurrency_payload(%Changeset{} = changeset) do
    new_entry = Ecto.get_meta(changeset.data, :state) == :built
    is_recurrency = get_field(changeset, :is_recurrency)
    valid? = changeset.valid?
    recurrency_entry_casted = get_change(changeset, :recurrency_entry)

    recurrency_casted =
      recurrency_entry_casted && get_change(recurrency_entry_casted, :recurrency)

    if Enum.all?([new_entry, is_recurrency, valid?, recurrency_entry_casted, recurrency_casted]) do
      entry_date = get_field(changeset, :date)

      module =
        changeset
        |> apply_action!(:insert)
        |> Map.from_struct()
        |> originator_module()

      payload = module.get_recurrency_payload(changeset)

      changeset =
        update_change(changeset, :recurrency_entry, fn re_changeset ->
          update_change(re_changeset, :recurrency, fn r_changeset ->
            put_change(
              r_changeset,
              :entry_payload,
              %{
                Date.to_iso8601(entry_date) => payload
              }
            )
            |> put_change(:date_start, entry_date)
          end)
          |> put_change(:original_date, entry_date)
        end)

      r_changeset =
        changeset
        |> get_change(:recurrency_entry)
        |> get_change(:recurrency)

      if get_field(r_changeset, :is_parcel) do
        parcel_start = get_field(r_changeset, :parcel_start)
        parcel_end = get_field(r_changeset, :parcel_end)

        update_change(changeset, :recurrency_entry, fn re_changeset ->
          re_changeset
          |> put_change(:parcel, parcel_start)
          |> put_change(:parcel_end, parcel_end)
        end)
      else
        changeset
      end
    else
      changeset
    end
  end

  defp put_updated_recurrency_payload(changeset) do
    if get_change(changeset, :recurrency_apply_forward) do
      module =
        changeset
        |> apply_action!(:insert)
        |> Map.from_struct()
        |> originator_module()

      payload = module.get_recurrency_payload(changeset)

      recurrency = changeset.data.recurrency_entry.recurrency

      recurrency_entry =
        changeset.data.recurrency_entry
        |> RecurrencyEntry.changeset(%{})
        |> put_change(
          :recurrency,
          recurrency
          |> Recurrency.changeset(%{})
          |> put_change(
            :entry_payload,
            Map.put(
              recurrency.entry_payload,
              Date.to_iso8601(get_field(changeset, :date)),
              payload
            )
          )
        )
        |> then(fn re_changeset ->
          if !re_changeset.data.id do
            %{re_changeset | action: :insert}
          else
            re_changeset
          end
        end)

      put_change(changeset, :recurrency_entry, recurrency_entry)
    else
      changeset
    end
  end

  defp validate_originator(changeset) do
    regular = get_field(changeset, :originator_regular)
    transfer = get_field(changeset, :originator_transfer)

    transfer_part = changeset.data.originator_transfer_part_id
    transfer_counter_part = changeset.data.originator_transfer_counter_part_id

    if !regular && !transfer && !transfer_part && !transfer_counter_part do
      changeset
      |> add_error(:originator_regular, "either must be regular or transfer entry")
      |> add_error(:originator_transfer_part, "either must be regular or transfer entry")
      |> add_error(:originator_transfer_counter_part, "either must be regular or transfer entry")
    else
      changeset
    end
  end

  def originator_module(entry) do
    entry
    |> Enum.filter(fn
      {_key, %{__struct__: st}} ->
        st !== Ecto.Association.NotLoaded
        
      _ -> true
    end)
    |> Enum.map(fn {key, _} ->
      key 
    end)
    |> Enum.map(&to_string/1)
    |> Enum.find(&String.starts_with?(&1, "originator_") && !String.ends_with?(&1, "_id"))
    |> String.replace("originator_", "")
    |> String.replace("_part", "")
    |> String.replace("_counter_part", "")
    |> String.capitalize()
    |> then(&("Elixir.Budget.Entries.Originator." <> &1))
    |> then(&String.to_existing_atom(&1))
  end

  def put_position(changeset) do
    if get_field(changeset, :position) in [nil, Decimal.new(-1)] do
      date = get_field(changeset, :date)

      max_position =
        from(
          e in __MODULE__,
          where: e.date == ^date,
          select: max(e.position)
        )
        |> Budget.Repo.one()
        |> case do
          nil ->
            Decimal.new(0)

          val ->
            val
        end

      put_change(changeset, :position, Decimal.add(max_position, 1))
    else
      changeset
    end
  end

  defp update_transfer(changeset) do
    transfer = get_change(changeset, :originator_transfer)

    if transfer do
        [transaction_field, transfer_field] =
            [:originator_transfer_part, :counter_part]
          
        put_assoc(changeset, transaction_field, Transfer.create_other_part(changeset, transfer, transfer_field))
    else
      value = get_change(changeset, :value)
      
      [transaction_field, transfer_field] =
        if changeset.data.originator_transfer_part_id do
          [:originator_transfer_part, :counter_part]
        else
          if changeset.data.originator_transfer_counter_part_id do
            [:originator_transfer_counter_part, :part]
          else
            [nil, nil]
          end
        end

      if value && transaction_field do
        put_assoc(changeset, transaction_field, Transfer.update_other_part(changeset, transaction_field, transfer_field))
      else
        changeset
      end

    end
  end
end

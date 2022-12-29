defmodule Budget.Entries.Entry do
  use Ecto.Schema
  import Ecto.Changeset

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

    belongs_to :account, Account

    belongs_to :originator_regular, Regular
    belongs_to :originator_transfer, Transfer

    field :is_recurrency, :boolean, virtual: true
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
      :recurrency_apply_forward
    ])
    |> validate_required([:date, :is_carried_out, :value, :account_id])
    |> cast_assoc(:recurrency_entry)
    |> cast_assoc(:originator_regular)
    |> cast_assoc(:originator_transfer)
    |> validate_originator()
    |> put_initial_recurrency_payload()
    |> put_updated_recurrency_payload()
  end

  defp put_initial_recurrency_payload(%Changeset{} = changeset) do
    new_entry = Ecto.get_meta(changeset.data, :state) == :built
    is_recurrency = get_field(changeset, :is_recurrency)
    valid? = changeset.valid?
    recurrency_entry_casted = get_change(changeset, :recurrency_entry)
    recurrency_casted = recurrency_entry_casted && get_change(recurrency_entry_casted, :recurrency)

    if Enum.all?([new_entry, is_recurrency, valid?, recurrency_entry_casted, recurrency_casted]) do
      module =
        changeset
        |> apply_action!(:insert)
        |> Map.from_struct()
        |> originator_module()

      payload = module.get_recurrency_payload(changeset)

      changeset = 
        update_change(changeset, :recurrency_entry, fn re_changeset ->
          update_change(re_changeset, :recurrency, fn r_changeset ->
            date_start = get_field(r_changeset, :date_start)

            put_change(
              r_changeset, 
              :entry_payload, 
              %{
                Date.to_iso8601(date_start) => payload
              }
            )
          end)
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
          |> put_change(:entry_payload, Map.put(recurrency.entry_payload, Date.to_iso8601(get_field(changeset, :date)), payload))
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

    if !regular && !transfer do
      changeset
      |> add_error(:originator_regular, "either must be regular or transfer entry")
      |> add_error(:originator_transfer, "either must be regular or transfer entry")
    else
      changeset
    end
  end


  def originator_module(entry) do
    entry
    |> Enum.map(fn {key, _} -> key end)
    |> Enum.map(&to_string/1)
    |> Enum.find(&String.starts_with?(&1, "originator_"))
    |> String.replace("originator_", "")
    |> String.capitalize()
    |> then(&("Elixir.Budget.Entries.Originator." <> &1))
    |> then(&String.to_existing_atom(&1))
  end
end

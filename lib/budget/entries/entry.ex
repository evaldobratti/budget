defmodule Budget.Entries.Entry do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.Entries.Account
  alias Budget.Entries.RecurrencyEntry
  alias Budget.Entries.Originators.Transfer
  alias Budget.Entries.Originators.Regular

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
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :date,
      :is_carried_out,
      :value,
      :account_id,
      :is_recurrency,
      :recurrency_apply_forward,
    ])
    |> validate_required([:date, :is_carried_out, :value, :account_id])
    |> cast_assoc(:recurrency_entry, with: &RecurrencyEntry.changeset_from_entry/2)
    |> cast_assoc(:originator_regular)
    |> cast_assoc(:originator_transfer)
    |> validate_originator()
  end

  def validate_originator(changeset) do
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

  @doc false
  def changeset_transient(entry, attrs) do
    entry
    |> cast(attrs, [
      :date,
      :is_carried_out,
      :value,
      :account_id,
      :is_recurrency,
      :recurrency_apply_forward,
    ])
    |> validate_required([:date, :is_carried_out, :value, :account_id])
    |> cast_assoc(:recurrency_entry, with: &RecurrencyEntry.changeset_from_entry_transient/2)
    |> cast_assoc(:originator_regular)
    |> cast_assoc(:originator_transfer)
    |> validate_originator()
  end
end

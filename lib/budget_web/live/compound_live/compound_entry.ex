defmodule BudgetWeb.CompoundLive.CompoundEntry do
  use Ecto.Schema
  import Ecto.Changeset


  alias Budget.Entries.Entry
  alias Budget.Entries.Recurrency

  require IEx

  embedded_schema do
    field :is_recurrency, :boolean, default: false
    belongs_to :entry, Budget.Entries.Entry
    belongs_to :recurrency, Recurrency
  end

  def changeset(compound, params \\ %{}) do
  IO.inspect(params)
    changeset = 
      compound
      |> cast(params, [:is_recurrency])
      |> cast_assoc(:entry)

    if get_field(changeset, :is_recurrency) do
      cast_assoc(changeset, :recurrency)
    else
      changeset
    end
  end

  def possible_recurrency_params(params) do
    entry_params = Map.get(params, "entry")

    changeset = Entry.changeset(%Entry{}, entry_params)

    %{
      "date_start" => get_field(changeset, :date),
      "description" => get_field(changeset, :description),
      "value" => get_field(changeset, :value),
      "account_id" => get_field(changeset, :account_id),
      "frequency" => "monthly"
    }
  end

end

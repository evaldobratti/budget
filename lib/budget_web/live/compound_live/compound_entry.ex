defmodule BudgetWeb.CompoundLive.CompoundEntry do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    belongs_to :entry, Budget.Entries.Entry
    field :is_recurrency, :boolean, default: false
    belongs_to :recurrency, Budget.Entries.Recurrency
  end

  def changeset(compound, params \\ %{}) do
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
end

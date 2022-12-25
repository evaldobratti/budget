defmodule Budget.Entries.Originators.Transfer do
  use Ecto.Schema

  alias Budget.Entries.Entry

  schema "originators_transfer" do
    has_many :entries, Entry, foreign_key: :originator_transfer

    timestamps()
  end
  
end

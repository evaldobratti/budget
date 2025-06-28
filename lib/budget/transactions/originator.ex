defmodule Budget.Transactions.Originator do
  @callback restore_for_recurrency(map()) :: map()
  @callback get_recurrency_payload(map()) :: map()
end

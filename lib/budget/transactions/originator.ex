defmodule Budget.Transactions.Originator do

  @callback restore_for_recurrency(map()) :: map()
  @callback description(map()) :: String.t
  @callback get_recurrency_payload(map()) :: map()
  
end

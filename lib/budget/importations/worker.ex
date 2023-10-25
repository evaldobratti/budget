defmodule Budget.Importations.Worker do
  alias Budget.Importations
  alias Budget.Hinter
  alias Budget.Importations.CreditCard.NuBank

  def process(user, file, importer \\ NuBank) do
    Budget.Repo.put_profile_id(user.id)

    result = importer.import(file)

    hinted_transactions =
      result.transactions
      |> Enum.map(fn
        %{type: :transaction} = transaction ->
          hint =
            case Hinter.hint_description(transaction.description) do
              [hint | _] -> hint.suggestion
              [] -> transaction.description
            end

          category = Hinter.hint_category(transaction.description, nil)

          transaction = %{
            "type" => :transaction,
            "ix" => transaction.ix,
            "date" => transaction.date,
            "value" => transaction.value,
            "originator" => "regular",
            "regular" => %{
              "category_id" => Map.get(category || %{}, :id),
              "description" => hint,
              "original_description" => transaction.description
            },
            "transfer" => %{
              "other_account_id" => nil
            }
          }

          hash = build_hash(transaction)

          conflict = Importations.has_conflict?(hash)

          transaction
          |> Map.put("conflict", conflict)
          |> Map.put("hash", hash)

        other ->
          other
      end)

    result = Map.put(result, :transactions, hinted_transactions)

    result
  end

  defp build_hash(%{
         "ix" => ix,
         "date" => date,
         "value" => value,
         "regular" => %{
           "original_description" => description
         }
       }) do
    "#{ix}-#{date}-#{value}-#{description}"
  end
end

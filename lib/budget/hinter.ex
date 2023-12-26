defmodule Budget.Hinter do
  import Ecto.Query

  alias Budget.Transactions.Transaction
  alias Budget.Repo
  alias Budget.Hinter.HintDescription

  def hint_description(original_description) do
    cleaned = Regex.replace(~r/ \d+\/\d+$/, original_description, "")

    from(
      h in HintDescription,
      order_by: fragment("similarity(original, ?) desc", ^cleaned),
      select: %{
        original: h.original,
        suggestion: h.transformed,
        rank: fragment("similarity(original, ?)", ^cleaned)
      }
    )
    |> Repo.all()
  end

  def hint_category(nil, _), do: nil
  def hint_category("", _), do: nil

  def hint_category(description, account_id) do
    query =
      from(
        t in Transaction,
        join: r in assoc(t, :originator_regular),
        left_join: c in assoc(r, :category),
        preload: [originator_regular: {r, category: c}],
        where: r.description == ^description,
        order_by: [desc: :date],
        limit: 1
      )

    query =
      if account_id do
        from(
          t in query,
          where: t.account_id == ^account_id
        )
      else
        query
      end

    query
    |> Repo.all()
    |> case do
      [] ->
        nil

      [%{originator_regular: regular}] ->
        regular.category
    end
  end

  # TODO put this to work
  def process_descriptions(descriptions) do
    descriptions
    |> Enum.map(fn {original, transformed} ->
      HintDescription.changeset(%HintDescription{}, %{
        original: original,
        transformed: transformed
      })
    end)
    |> Enum.map(&Repo.insert/1)
  end
end

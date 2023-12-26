defmodule Budget.Transactions do
  alias Budget.Transactions.Originator
  alias Budget.Repo

  import Ecto.Query

  alias Budget.Transactions.{
    Account,
    Transaction,
    Recurrency,
    RecurrencyTransaction,
    Category
  }

  @doc """
  Returns the list of accounts.

  ## Examples

      iex> list_accounts()
      [%Account{}, ...]

  """
  def list_accounts do
    Repo.all(from(p in Account, order_by: p.name))
  end

  @doc """
  Gets a single account.

  Raises if the Account does not exist.

  ## Examples

      iex> get_account!(123)
      %Account{}

  """
  def get_account!(id), do: Repo.get!(Account, id)

  @doc """
  Creates a account.

  ## Examples

      iex> create_account(%{field: value})
      {:ok, %Account{}}

      iex> create_account(%{field: bad_value})
      {:error, ...}

  """
  def create_account(attrs \\ %{}) do
    %Account{}
    |> Account.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a account.

  ## Examples

      iex> update_account(account, %{field: new_value})
      {:ok, %Account{}}

      iex> update_account(account, %{field: bad_value})
      {:error, ...}

  """
  def update_account(%Account{} = account, attrs) do
    account
    |> Account.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Account.

  ## Examples

      iex> delete_account(account)
      {:ok, %Account{}}

      iex> delete_account(account)
      {:error, ...}

  """
  def delete_account(%Account{} = _account) do
    raise "TODO"
  end

  @doc """
  Returns a data structure for tracking account changes.

  ## Examples

      iex> change_account(account)
      %Todo{...}

  """
  def change_account(%Account{} = account, attrs \\ %{}) do
    Account.changeset(account, attrs)
  end

  def get_transaction!("recurrency" <> _ = id) do
    {:error, {:query_for_transient_transaction, id}}
  end

  def get_transaction!(id) do
    Repo.get(transaction_query(), id)
  end

  def balance_at(date, opts \\ []) do
    account_ids = Keyword.get(opts, :account_ids, [])
    category_ids = Keyword.get(opts, :category_ids, [])

    transactions =
      from(
        t in Transaction,
        join: a in assoc(t, :account),
        as: :account,
        left_join: r in assoc(t, :originator_regular),
        left_join: c in assoc(r, :category),
        as: :category,
        where: t.date <= ^date,
        select: coalesce(sum(t.value), 0)
      )
      |> where_opts(opts)
      |> Repo.one()

    initials =
      from(
        a in Account,
        as: :account,
        select: coalesce(sum(a.initial_balance), 0)
      )
      |> where_opts(opts)
      |> Repo.one()

    # TODO make this function use transactions_in_period()
    recurrencies =
      find_recurrencies()
      |> Enum.map(&recurrency_transactions(&1, date))
      |> List.flatten()
      |> Enum.filter(&(&1.account_id in account_ids || account_ids == []))
      |> Enum.filter(fn transaction ->
        if category_ids == [] do
          true
        else
          if transaction.originator_regular do
            transaction.originator_regular.category_id in category_ids
          else
            true
          end
        end
      end)
      |> Enum.map(& &1.value)
      |> Enum.reduce(Decimal.new(0), &Decimal.add(&1, &2))

    transactions
    |> Decimal.add(initials)
    |> Decimal.add(recurrencies)
  end

  def change_recurrency(%Recurrency{} = recurrency, attrs \\ %{}) do
    Recurrency.changeset(recurrency, attrs)
  end

  def update_recurrency(%Recurrency{} = recurrency, attrs) do
    recurrency
    |> Recurrency.changeset(attrs)
    |> Repo.update()
  end

  def create_recurrency(attrs \\ %{}) do
    %Recurrency{}
    |> Recurrency.changeset(attrs)
    |> Repo.insert()
  end

  def recurrency_transactions(recurrency, until_date) do
    Recurrency.transactions(recurrency, until_date)
  end

  def find_recurrencies() do
    from(
      r in Recurrency,
      preload: [recurrency_transactions: :transaction]
    )
    |> Repo.all()
  end

  def transactions_in_period(date_start, date_end, opts \\ []) do
    regular = regular_transactions_in_period(date_start, date_end, opts)
    recurrency = recurrency_transactions_in_period(date_start, date_end, opts)

    (regular ++ recurrency)
    |> Enum.sort_by(
      & &1.value,
      &(Decimal.gt?(&1, &2) || Decimal.eq?(&1, &2))
    )
    |> Enum.sort_by(&Decimal.to_float(&1.position))
    |> Enum.sort_by(
      & &1.date,
      &(Timex.before?(&1, &2) || Timex.equal?(&1, &2))
    )
  end

  defp transaction_query() do
    from(
      e in Transaction,
      as: :transaction,
      join: a in assoc(e, :account),
      as: :account,
      left_join: re in assoc(e, :recurrency_transaction),
      left_join: r in assoc(re, :recurrency),
      left_join: regular in assoc(e, :originator_regular),
      left_join: c in assoc(regular, :category),
      as: :category,
      left_join: tp in assoc(e, :originator_transfer_part),
      left_join: tpe in assoc(tp, :counter_part),
      left_join: tpea in assoc(tpe, :account),
      left_join: tcp in assoc(e, :originator_transfer_counter_part),
      left_join: tcpe in assoc(tcp, :part),
      left_join: tcpea in assoc(tcpe, :account),
      preload: [
        account: a,
        recurrency_transaction: {re, recurrency: r},
        originator_regular: {regular, category: c},
        originator_transfer_part: {tp, counter_part: {tpe, account: tpea}},
        originator_transfer_counter_part: {tcp, part: {tcpe, account: tcpea}}
      ],
      order_by: [e.date, e.position, regular.description],
      select_merge: %{is_recurrency: not is_nil(r.id)}
    )
  end

  defp regular_transactions_in_period(date_start, date_end, opts) do
    query =
      transaction_query()
      |> where([transaction: t], t.date >= ^date_start and t.date <= ^date_end)
      |> where_opts(opts)

    Repo.all(query)
  end

  defp recurrency_transactions_in_period(date_start, date_end, opts) do
    account_ids = Keyword.get(opts, :account_ids, [])
    category_ids = Keyword.get(opts, :category_ids, [])

    recurrencies = find_recurrencies()

    recurrencies
    |> Enum.reduce([], fn r, acc ->
      [Recurrency.transactions(r, date_end) | acc]
    end)
    |> List.flatten()
    |> Enum.filter(&(&1.account_id in account_ids || account_ids == []))
    |> Enum.filter(fn transaction ->
      if category_ids == [] do
        true
      else
        if transaction.originator_regular do
          transaction.originator_regular.category_id in category_ids
        else
          true
        end
      end
    end)
    |> Enum.filter(&Timex.between?(&1.date, date_start, date_end, inclusive: true))
  end

  defp where_opts(query, opts) do
    account_ids = Keyword.get(opts, :account_ids, [])
    category_ids = Keyword.get(opts, :category_ids, [])

    query =
      if has_named_binding?(query, :account) do
        from([account: a] in query,
          where: a.id in ^account_ids or fragment("?::int = 0", ^length(account_ids))
        )
      else
        query
      end

    query =
      if has_named_binding?(query, :category) do
        from([category: c] in query,
          where: c.id in ^category_ids or fragment("?::int = 0", ^length(category_ids))
        )
      else
        query
      end

    query
  end

  def get_recurrency!(id) do
    from(
      r in Recurrency,
      preload: [recurrency_transactions: [transaction: :originator_regular]]
    )
    |> Repo.get!(id)
  end

  def delete_transaction_state("recurrency" <> _ = transaction_id) do
    transaction_id
    |> encarnate_transient_transaction()
    |> calculate_transaction_state()
  end

  def delete_transaction_state(transaction_id) do
    from(
      t in Transaction,
      preload: [recurrency_transaction: [{:recurrency, :recurrency_transactions}]],
      where: t.id == ^transaction_id
    )
    |> Repo.one()
    |> calculate_transaction_state()
  end

  defp calculate_transaction_state(transaction = %Transaction{}) do
    if transaction.recurrency_transaction do
      any_future =
        transaction.recurrency_transaction.recurrency.recurrency_transactions
        |> Enum.filter(& &1.transaction_id)
        |> Enum.any?(&Timex.after?(&1.original_date, transaction.date))

      if any_future do
        :recurrency_with_future
      else
        :recurrency
      end
    else
      :regular
    end
  end

  def encarnate_transient_transaction(transaction_id) do
    [_, recurrency_id, year, month, day, ix] = String.split(transaction_id, "-")

    {:ok, date} =
      Date.new(String.to_integer(year), String.to_integer(month), String.to_integer(day))

    recurrency_id
    |> get_recurrency!()
    |> recurrency_transactions(date)
    |> Enum.filter(&(&1.date == date))
    |> Enum.at(String.to_integer(ix))
  end

  def delete_transaction(transaction_id, mode)

  def delete_transaction("recurrency" <> _ = transaction_id, mode) do
    transient = encarnate_transient_transaction(transaction_id)

    Ecto.Multi.new()
    |> Ecto.Multi.run(:transaction, fn _repo, _changes ->
      Transaction.Form.apply_update(transient, %{})
    end)
    |> Ecto.Multi.run(:actions, fn _repo, %{transaction: transaction} ->
      delete_transaction(transaction.id, mode)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{transaction: transaction, actions: actions}} ->
        {:ok, %{transaction: transaction} |> Map.merge(actions)}

      error ->
        error
    end
  end

  def delete_transaction(transaction_id, "transaction") do
    transaction = get_transaction!(transaction_id)

    delete_with_recurrency(transaction, [transaction_id], false)
  end

  def delete_transaction(transaction_id, "recurrency-keep-future") do
    transaction = get_transaction!(transaction_id)

    delete_with_recurrency(transaction, [transaction_id], true)
  end

  def delete_transaction(transaction_id, "recurrency-all") do
    transaction = get_transaction!(transaction_id)

    transaction_ids =
      from(
        rt in RecurrencyTransaction,
        where:
          rt.recurrency_id == ^transaction.recurrency_transaction.recurrency_id and
            rt.original_date >= ^transaction.recurrency_transaction.original_date,
        select: rt.transaction_id
      )
      |> Repo.all()

    delete_with_recurrency(transaction, transaction_ids, true)
  end

  defp delete_with_recurrency(%Transaction{} = subject, transaction_ids, end_recurrency) do
    recurrency_change = fn repo, _ ->
      if end_recurrency && subject.recurrency_transaction &&
           subject.recurrency_transaction.recurrency do
        subject.recurrency_transaction.recurrency
        |> Ecto.Changeset.change(%{
          date_end: Timex.shift(subject.recurrency_transaction.original_date, days: -1)
        })
        |> repo.update()
      else
        {:ok, :nothing_changed}
      end
    end

    module = originator_module(subject)
    prepare = module.delete(transaction_ids)

    Ecto.Multi.new()
    |> Ecto.Multi.merge(prepare)
    |> Ecto.Multi.update_all(
      :update_recurrency_transactions,
      fn %{transactions: transactions} ->
        from(
          rt in RecurrencyTransaction,
          where: rt.transaction_id in ^transactions
        )
      end,
      set: [transaction_id: nil]
    )
    |> Ecto.Multi.delete_all(:delete_transactions, fn %{transactions: transactions} ->
      from(t in Transaction, where: t.id in ^transactions)
    end)
    |> Ecto.Multi.delete_all(:delete_originators, fn %{originators: originators} ->
      from(t in module, where: t.id in ^originators)
    end)
    |> Ecto.Multi.run(:recurrency, recurrency_change)
    |> Repo.transaction()
  end

  def create_category(attrs, parent \\ nil) do
    %Category{}
    |> Category.changeset(attrs)
    |> then(fn changeset ->
      if parent do
        Category.make_child_of(changeset, parent)
      else
        changeset
      end
    end)
    |> Repo.insert()
  end

  def update_category(category, attrs) do
    category
    |> Category.changeset(attrs)
    |> Repo.update()
  end

  def list_categories_arranged do
    list_categories()
    |> Category.arrange()
  end

  def list_categories() do
    from(
      c in Category,
      left_join: r in Originator.Regular,
      on: r.category_id == c.id,
      group_by: [c.id, c.name, c.path, c.inserted_at, c.updated_at],
      select_merge: %{transactions_count: count(r.id)}
    )
    |> Repo.all()
  end

  def change_category(category, attrs \\ %{}) do
    category
    |> Category.changeset(attrs)
  end

  def get_category!(id), do: Repo.get!(Category, id)
  def get_category_by_name!(name), do: from(c in Category, where: c.name == ^name) |> Repo.one!()

  def update_order(old_index, new_index, transactions) do
    transaction_to_update = Enum.at(transactions, old_index)
    list_wo_element = List.delete_at(transactions, old_index)

    new_order = List.insert_at(list_wo_element, new_index, transaction_to_update)

    transaction_before = if new_index == 0, do: nil, else: Enum.at(new_order, new_index - 1)
    transaction_after = Enum.at(new_order, new_index + 1)

    put_transaction_between(transaction_to_update, [transaction_before, transaction_after])
  end

  def put_transaction_between(_transaction, [nil, nil]) do
    {:error, "no reference transaction given"}
  end

  def put_transaction_between(transaction, [nil, transaction_after]) do
    position = transaction_after.position

    date =
      if transaction.date == transaction_after.date do
        transaction.date
      else
        transaction_after.date
      end

    before_position =
      from(
        t in Transaction,
        where: t.position < ^position and t.date == ^date,
        order_by: [desc: t.position],
        limit: 1,
        select: t.position
      )
      |> Repo.one()
      |> case do
        nil ->
          Decimal.new(0)

        val ->
          val
      end

    Transaction.Form.apply_update(transaction, %{
      date: date,
      position: Decimal.add(before_position, position) |> Decimal.div(2)
    })
  end

  def put_transaction_between(%Transaction{} = transaction, [
        transaction_before = %Transaction{},
        transaction_after
      ]) do
    position = transaction_before.position

    date =
      if transaction.date !== transaction_before.date &&
           (transaction_after == nil || transaction.date !== transaction_after.date) do
        transaction_before.date
      else
        transaction.date
      end

    after_position =
      from(
        t in Transaction,
        where: t.position > ^position and t.date == ^date,
        order_by: t.position,
        limit: 1,
        select: t.position
      )
      |> Repo.one()
      |> case do
        nil ->
          Decimal.add(transaction_before.position, 1)

        val ->
          val
      end

    Transaction.Form.apply_update(transaction, %{
      date: date,
      position: Decimal.add(after_position, position) |> Decimal.div(2)
    })
  end

  def next_position_for_date(date) do
    max_position =
      from(
        t in Transaction,
        where: t.date == ^date,
        select: max(t.position)
      )
      |> Budget.Repo.one()
      |> case do
        nil ->
          Decimal.new(0)

        val ->
          val
      end

    Decimal.add(max_position, 1)
  end

  def originator(%Transaction{} = transaction) do
    [
      transaction.originator_regular,
      transaction.originator_transfer_part,
      transaction.originator_transfer_counter_part
    ]
    |> Enum.find(&(Ecto.assoc_loaded?(&1) && &1 != nil))
  end

  def originator_module(%Transaction{} = transaction) do
    [
      transaction.originator_regular,
      transaction.originator_transfer_part,
      transaction.originator_transfer_counter_part
    ]
    |> Enum.find(&(Ecto.assoc_loaded?(&1) && &1 != nil))
    |> then(& &1.__struct__)
  end

  def get_counter_part(%Transaction{} = transaction) do
    originator = originator(transaction)

    cond do
      transaction.originator_transfer_part == originator ->
        transaction.originator_transfer_part.counter_part

      transaction.originator_transfer_counter_part == originator ->
        transaction.originator_transfer_counter_part.part

      true ->
        raise "not a transfer transaction"
    end
  end

  def list_descriptions do
    from(
      t in Transaction,
      join: r in assoc(t, :originator_regular),
      distinct: r.description,
      select: r.description
    )
    |> Repo.all()
  end
end

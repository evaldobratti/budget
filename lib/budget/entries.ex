defmodule Budget.Entries do
  alias Budget.Repo

  import Ecto.Query

  alias Budget.Entries.{
    Account,
    Entry,
    Recurrency,
    RecurrencyEntry,
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

  def change_entry(%Entry{} = entry, attrs \\ %{}) do
    Entry.changeset(entry, attrs)
  end

  def update_entry(%Entry{} = entry, attrs) do
    entry
    |> Entry.changeset(attrs)
    |> Repo.update()
  end

  def create_entry(entry \\ %Entry{}, attrs) do
    case entry.id do
      "recurrency" <> _ ->
        Ecto.Multi.new()
        |> Ecto.Multi.insert(:entry, Map.put(entry, :id, nil))
        |> Ecto.Multi.update(:entry_update, fn %{entry: entry} ->
          Entry.changeset(entry, attrs)
        end)
        |> Repo.transaction()
        |> case do
          {:ok, %{entry_update: entry_update}} ->
            {:ok, entry_update}

          error ->
            error
        end

      _ ->
        Ecto.Multi.new()
        |> Ecto.Multi.run(:entry, fn _repo, _changes ->
          %Entry{}
          |> Entry.changeset(attrs)
          |> Repo.insert()
        end)
        |> Ecto.Multi.run(:originator_post_insert, fn _repo, changes ->
          case changes.entry do
            %{
              originator_transfer_part: %{
                counter_part: %Entry{} = counter_part
              },
              recurrency_entry: %RecurrencyEntry{} = recurrency_entry
            } ->
              Repo.insert(%RecurrencyEntry{
                entry_id: counter_part.id,
                recurrency_id: recurrency_entry.recurrency_id,
                original_date: recurrency_entry.original_date,
                parcel: recurrency_entry.parcel,
                parcel_end: recurrency_entry.parcel_end
              })

            _ ->
              {:ok, :nothing_done}
          end
        end)
        |> Repo.transaction()
        |> case do
          {:ok, %{entry: entry}} ->
            {:ok, entry}

          error ->
            error
        end
    end
  end

  def get_entry!("recurrency" <> _ = id) do
    {:error, {:query_for_transient_entry, id}}
  end

  def get_entry!(id) do
    Repo.get(entry_query(), id)
  end

  def balance_at(accounts_ids, date) do
    entries =
      from(
        e in Entry,
        join: a in assoc(e, :account),
        as: :account,
        where: e.date <= ^date,
        select: coalesce(sum(e.value), 0)
      )
      |> where_account_in(accounts_ids)
      |> Repo.one()

    initials =
      from(
        a in Account,
        as: :account,
        select: coalesce(sum(a.initial_balance), 0)
      )
      |> where_account_in(accounts_ids)
      |> Repo.one()

    recurrencies =
      find_recurrencies()
      |> Enum.map(&recurrency_entries(&1, date))
      |> List.flatten()
      |> Enum.filter(&(&1.account_id in accounts_ids || accounts_ids == []))
      |> Enum.map(& &1.value)
      |> Enum.reduce(Decimal.new(0), &Decimal.add(&1, &2))

    entries
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

  def recurrency_entries(recurrency, until_date) do
    Recurrency.entries(recurrency, until_date)
  end

  def find_recurrencies() do
    from(
      r in Recurrency,
      preload: [recurrency_entries: :entry]
    )
    |> Repo.all()
  end

  def entries_in_period(account_ids, date_start, date_end) do
    regular = regular_entries_in_period(account_ids, date_start, date_end)
    recurrency = recurrency_entries_in_period(account_ids, date_start, date_end)

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

  defp entry_query() do
    from(
      e in Entry,
      as: :entry,
      join: a in assoc(e, :account),
      as: :account,
      left_join: re in assoc(e, :recurrency_entry),
      left_join: r in assoc(re, :recurrency),
      left_join: regular in assoc(e, :originator_regular),
      left_join: c in assoc(regular, :category),
      left_join: tp in assoc(e, :originator_transfer_part),
      left_join: tpe in assoc(tp, :counter_part),
      left_join: tpea in assoc(tpe, :account),
      left_join: tcp in assoc(e, :originator_transfer_counter_part),
      left_join: tcpe in assoc(tcp, :part),
      left_join: tcpea in assoc(tcpe, :account),
      preload: [
        account: a,
        recurrency_entry: {re, recurrency: r},
        originator_regular: {regular, category: c},
        originator_transfer_part: {tp, counter_part: {tpe, account: tpea}},
        originator_transfer_counter_part: {tcp, part: {tcpe, account: tcpea}}
      ],
      order_by: [e.date, e.position, regular.description],
      select_merge: %{is_recurrency: not is_nil(r.id)}
    )
  end

  defp regular_entries_in_period(account_ids, date_start, date_end) do
    query =
      entry_query()
      |> where([entry: e], e.date >= ^date_start and e.date <= ^date_end)
      |> where_account_in(account_ids)

    Repo.all(query)
  end

  defp recurrency_entries_in_period(account_ids, date_start, date_end) do
    recurrencies = find_recurrencies()

    recurrencies
    |> Enum.reduce([], fn r, acc ->
      [Recurrency.entries(r, date_end) | acc]
    end)
    |> List.flatten()
    |> Enum.filter(&(&1.account_id in account_ids || account_ids == []))
    |> Enum.filter(&Timex.between?(&1.date, date_start, date_end, inclusive: true))
  end

  defp where_account_in(query, account_ids) do
    from([account: a] in query,
      where: a.id in ^account_ids or fragment("?::int = 0", ^length(account_ids))
    )
  end

  def get_recurrency!(id) do
    from(
      r in Recurrency,
      preload: [recurrency_entries: [entry: :originator_regular]]
    )
    |> Repo.get!(id)
  end

  def delete_entry_state("recurrency" <> _ = entry_id) do
    entry_id
    |> encarnate_transient_entry()
    |> calculate_entry_state()
  end

  def delete_entry_state(entry_id) do
    from(
      e in Entry,
      preload: [recurrency_entry: [{:recurrency, :recurrency_entries}]],
      where: e.id == ^entry_id
    )
    |> Repo.one()
    |> calculate_entry_state()
  end

  defp calculate_entry_state(entry = %Entry{}) do
    if entry.recurrency_entry do
      any_future =
        entry.recurrency_entry.recurrency.recurrency_entries
        |> Enum.filter(& &1.entry_id)
        |> Enum.any?(&Timex.after?(&1.original_date, entry.date))

      if any_future do
        :recurrency_with_future
      else
        :recurrency
      end
    else
      :regular
    end
  end

  def encarnate_transient_entry(entry_id) do
    [_, recurrency_id, year, month, day | maybe_ix_tail] = String.split(entry_id, "-")

    {:ok, date} =
      Date.new(String.to_integer(year), String.to_integer(month), String.to_integer(day))

    recurrency_id
    |> get_recurrency!()
    |> recurrency_entries(date)
    |> Enum.filter(&(&1.date == date))
    |> then(fn 
      [e] -> e
      list -> 
        [ix] = maybe_ix_tail
        Enum.at(list, String.to_integer(ix))
    end)
  end

  def delete_entry(entry_id, mode)

  def delete_entry("recurrency" <> _ = entry_id, mode) do
    transient = encarnate_transient_entry(entry_id)

    Ecto.Multi.new()
    |> Ecto.Multi.run(:entry, fn _repo, _changes ->
      create_entry(transient, %{})
    end)
    |> Ecto.Multi.run(:actions, fn _repo, %{entry: entry} ->
      delete_entry(entry.id, mode)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{entry: entry, actions: actions}} ->
        {:ok, %{entry: entry} |> Map.merge(actions)}

      error ->
        error
    end
  end

  def delete_entry(entry_id, "entry") do
    entry = get_entry!(entry_id)

    Ecto.Multi.new()
    |> Ecto.Multi.update_all(
      :nulify_recurrency_entry,
      from(re in RecurrencyEntry, where: re.entry_id == ^entry_id),
      set: [entry_id: nil]
    )
    |> Ecto.Multi.delete_all(:delete_entry, from(Entry, where: [id: ^entry.id]))
    |> Repo.transaction()
  end

  def delete_entry(entry_id, "recurrency-keep-future") do
    entry = get_entry!(entry_id)

    recurrency_change =
      entry.recurrency_entry.recurrency
      |> change_recurrency(%{
        date_end: Timex.shift(entry.recurrency_entry.original_date, days: -1)
      })

    Ecto.Multi.new()
    |> Ecto.Multi.update_all(
      :nulify_recurrency_entry,
      from(re in RecurrencyEntry, where: re.entry_id == ^entry_id),
      set: [entry_id: nil]
    )
    |> Ecto.Multi.update(:recurrency, recurrency_change)
    |> Ecto.Multi.delete_all(:delete_entry, from(Entry, where: [id: ^entry.id]))
    |> Repo.transaction()
  end

  def delete_entry(entry_id, "recurrency-all") do
    entry = get_entry!(entry_id)
    recurrency = entry.recurrency_entry.recurrency

    recurrency_change =
      recurrency
      |> change_recurrency(%{
        date_end: Timex.shift(entry.recurrency_entry.original_date, days: -1)
      })

    affected_recurrency_entries =
      from(
        re in RecurrencyEntry,
        where:
          re.recurrency_id == ^recurrency.id and
            re.original_date >= ^entry.recurrency_entry.original_date,
        preload: :entry
      )
      |> Repo.all()

    affected_re_ids = affected_recurrency_entries |> Enum.map(& &1.id)

    affected_entry_ids =
      affected_recurrency_entries |> Enum.filter(& &1.entry) |> Enum.map(& &1.entry.id)

    Ecto.Multi.new()
    |> Ecto.Multi.update_all(
      :nulify_recurrency_entry,
      from(re in RecurrencyEntry, where: re.id in ^affected_re_ids),
      set: [entry_id: nil]
    )
    |> Ecto.Multi.delete_all(
      :delete_entry,
      from(e in Entry, where: e.id in ^affected_entry_ids)
    )
    |> Ecto.Multi.update(:recurrency, recurrency_change)
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
    Category
    |> Repo.all()
  end

  def change_category(category, attrs \\ %{}) do
    category
    |> Category.changeset(attrs)
  end

  def get_category!(id), do: Repo.get!(Category, id)

  def update_order(old_index, new_index, entries) do
    entry_to_update = Enum.at(entries, old_index)
    list_wo_element = List.delete_at(entries, old_index)

    new_order = List.insert_at(list_wo_element, new_index, entry_to_update)

    entry_before = if new_index == 0, do: nil, else: Enum.at(new_order, new_index - 1)
    entry_after = Enum.at(new_order, new_index + 1)

    put_entry_between(entry_to_update, [entry_before, entry_after])
  end

  def put_entry_between(_entry, [nil, nil]) do
    {:error, "no reference transaction given"}
  end

  def put_entry_between(entry, [nil, entry_after]) do
    position = entry_after.position

    date =
      if entry.date == entry_after.date do
        entry.date
      else
        entry_after.date
      end

    before_position =
      from(
        e in Entry,
        where: e.position < ^position and e.date == ^date,
        order_by: [desc: e.position],
        limit: 1,
        select: e.position
      )
      |> Repo.one()
      |> case do
        nil ->
          Decimal.new(0)

        val ->
          val
      end

    Entry.Form.apply_update(entry, %{
      date: date,
      position: Decimal.add(before_position, position) |> Decimal.div(2)
    })
  end

  def put_entry_between(entry, [entry_before = %Entry{}, entry_after]) do
    position = entry_before.position

    date =
      if entry.date !== entry_before.date &&
           (entry_after == nil || entry.date !== entry_after.date) do
        entry_before.date
      else
        entry.date
      end

    after_position =
      from(
        e in Entry,
        where: e.position > ^position and e.date == ^date,
        order_by: e.position,
        limit: 1,
        select: e.position
      )
      |> Repo.one()
      |> case do
        nil ->
          Decimal.add(entry_before.position, 1)

        val ->
          val
      end

    Entry.Form.apply_update(entry, %{
      date: date,
      position: Decimal.add(after_position, position) |> Decimal.div(2)
    })
  end

  def next_position_for_date(date) do
    max_position =
      from(
        e in Entry,
        where: e.date == ^date,
        select: max(e.position)
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

  def originator(%Entry{} = transaction) do
    [
      transaction.originator_regular,
      transaction.originator_transfer_part,
      transaction.originator_transfer_counter_part
    ]
    |> Enum.find(& Ecto.assoc_loaded?(&1) && &1 != nil)
  end

  def get_counter_part(%Entry{} = transaction) do
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
end

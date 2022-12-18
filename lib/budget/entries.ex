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
    Repo.all(from p in Account, order_by: p.name)
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

  def change_transient_entry(%Entry{} = entry, attrs \\ %{}) do
    Entry.changeset_transient(entry, attrs)
  end

  def update_entry(%Entry{} = entry, attrs) do
    entry
    |> Entry.changeset(attrs)
    |> Repo.update()
  end

  def create_transient_entry(%Entry{} = entry, attrs \\ %{}) do
    # TODO add validation that id starts with recurrency
    changeset =
      entry
      |> Map.put(:id, nil)
      |> Entry.changeset_transient(attrs)

    check_ending_recurrency(changeset)
  end

  defp check_ending_recurrency(
         %Ecto.Changeset{changes: %{recurrency_apply_forward: true}, valid?: true} = changeset
       ) do
    original_date = changeset.data.recurrency_entry.original_date

    {:ok, entry} = Ecto.Changeset.apply_action(changeset, :insert)
    previous_recurrency = get_recurrency!(entry.recurrency_entry.recurrency_id)

    parcel_regex = ~r/ \((\d+)\/\d+\)/

    [current_parcel, description] =
      case Regex.run(parcel_regex, entry.description) do
        [_, parcel] ->
          [String.to_integer(parcel), Regex.replace(parcel_regex, entry.description, "")]

        _ ->
          [nil, entry.description]
      end

    {:ok, entry} =
      create_entry(%{
        date: entry.date,
        description: description,
        value: entry.value,
        is_carried_out: entry.is_carried_out,
        account_id: entry.account_id,
        category_id: entry.category_id,
        recurrency_entry: %{
          original_date: entry.date,
          recurrency: %{
            date_start: original_date,
            date_end: previous_recurrency.date_end,
            frequency: previous_recurrency.frequency,
            is_forever: previous_recurrency.is_forever,
            is_parcel: previous_recurrency.is_parcel,
            parcel_start: current_parcel,
            parcel_end: previous_recurrency.parcel_end,
            account_id: entry.account_id,
            category_id: entry.category_id,
            description: description,
            value: entry.value,
          }
        }
      })

    update_recurrency(changeset.data.recurrency_entry.recurrency, %{
      date_end: original_date |> Timex.shift(days: -1)
    })

    {:ok, entry}
  end

  defp check_ending_recurrency(changeset) do
    changeset
    |> Repo.insert()
  end

  def create_entry(attrs \\ %{}) do
    %Entry{}
    |> Entry.changeset(attrs)
    |> Recurrency.apply_any_description_update()
    |> Repo.insert()
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
      accounts_ids
      |> find_recurrencies()
      |> Enum.map(&recurrency_entries(&1, date))
      |> List.flatten()
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

  def find_recurrencies(accounts_ids) do
    from(
      r in Recurrency,
      join: a in assoc(r, :account),
      as: :account,
      preload: [recurrency_entries: :entry, account: a, category: []]
    )
    |> where_account_in(accounts_ids)
    |> Repo.all()
  end

  def entries_in_period(account_ids, date_start, date_end) do
    regular = regular_entries_in_period(account_ids, date_start, date_end)
    recurrency = recurrency_entries_in_period(account_ids, date_start, date_end)

    (regular ++ recurrency)
    |> Enum.sort(&Timex.before?(&1.date, &2.date))
  end

  defp entry_query() do
    from(
      e in Entry,
      as: :entry,
      join: a in assoc(e, :account),
      as: :account,
      left_join: re in assoc(e, :recurrency_entry),
      left_join: r in assoc(re, :recurrency),
      join: c in assoc(e, :category),
      preload: [account: a, recurrency_entry: {re, recurrency: r}, category: c],
      order_by: [e.date, e.description],
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
    recurrencies = find_recurrencies(account_ids)

    recurrencies
    |> Enum.reduce([], fn r, acc ->
      [Recurrency.entries(r, date_end) | acc]
    end)
    |> List.flatten()
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
      preload: [recurrency_entries: :entry]
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
        Enum.any?(
          entry.recurrency_entry.recurrency.recurrency_entries,
          &Timex.after?(&1.original_date, entry.date)
        )

      if any_future do
        :recurrency_with_future
      else
        :recurrency
      end
    else
      :regular
    end
  end

  defp encarnate_transient_entry(entry_id) do
    [_, recurrency_id, year, month, day] = String.split(entry_id, "-")

    {:ok, date} =
      Date.new(String.to_integer(year), String.to_integer(month), String.to_integer(day))

    recurrency_id
    |> get_recurrency!()
    |> recurrency_entries(date)
    |> Enum.find(&(&1.date == date))
  end

  def delete_entry(entry_id, mode)

  def delete_entry("recurrency" <> _ = entry_id, mode) do
    transient = encarnate_transient_entry(entry_id)

    Ecto.Multi.new()
    |> Ecto.Multi.run(:entry, fn _repo, _changes ->
      create_transient_entry(transient, %{})
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
      |> change_recurrency(%{date_end: Timex.shift(entry.date, days: -1)})

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
      |> change_recurrency(%{date_end: Timex.shift(entry.date, days: -1)})

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
    affected_entry_ids = affected_recurrency_entries |> Enum.map(& &1.entry.id)

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
    |> Category.arrange
  end

  def list_categories() do
    Category
    |> Repo.all
  end

  def change_category(category, attrs \\ %{}) do
    category
    |> Category.changeset(attrs)
  end

  def get_category!(id), do: Repo.get!(Category, id)
end

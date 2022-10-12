defmodule Budget.Entries do
  alias Budget.Repo

  import Ecto.Query

  alias Budget.Entries.{
    Account,
    Entry,
    Recurrency
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
    entry
    |> Map.put(:id, nil)
    |> Entry.changeset_transient(attrs)
    |> Repo.insert()
  end


  def create_entry(attrs \\ %{}) do
    %Entry{}
    |> Entry.changeset(attrs)
    |> Repo.insert()
  end


  def get_entry!(id) do
    Repo.get(Entry, id)
  end

  def balance_at(accounts_ids, date) do
    entries = 
      from(
        e in Entry,
        join: a in assoc(e, :account), as: :account,
        where: e.date <= ^date,
        select: coalesce(sum(e.value), 0)
      )
      |> where_account_in(accounts_ids)
      |> Repo.one()

    initials = 
      from(
        a in Account, as: :account,
        select: coalesce(sum(a.initial_balance), 0)
      )
      |> where_account_in(accounts_ids)
      |> Repo.one()

    recurrencies = 
      find_recurrencies(accounts_ids)
      |> Enum.map(& recurrency_entries(&1, date))
      |> List.flatten()
      |> Enum.map(& &1.value)
      |> Enum.reduce(Decimal.new(0), & Decimal.add(&1, &2))

    entries
    |> Decimal.add( initials)
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
    query = 
      from(
        r in Recurrency,
        join: a in assoc(r, :account), as: :account,
        preload: [:recurrency_entries, {:account, a}]
      )

      # agora tem que colocar a recorrencia nos saldos
      # rastrear lançamentos já criados ou nao (por ex, o lancamento originador aparece duplicado)

    query = 
      if length(accounts_ids) == 0 do
        query
      else
        where(query, [e], e.account_id in ^accounts_ids)
      end

    Repo.all(query)
  end


  def entries_in_period(account_ids, date_start, date_end) do
    regular = regular_entries_in_period(account_ids, date_start, date_end)
    recurrency = recurrency_entries_in_period(account_ids, date_start, date_end)

    regular ++ recurrency
    |> Enum.sort(&Timex.before?(&1.date, &2.date))
  end

  defp regular_entries_in_period(account_ids, date_start, date_end) do
    query = 
      from(
        e in Entry,
        where: e.date >= ^date_start and e.date <= ^date_end,
        join: a in assoc(e, :account), as: :account,
        left_join: re in assoc(e, :recurrency_entry),
        left_join: r in assoc(re, :recurrency),
        preload: [account: a, recurrency_entry: :recurrency],
        order_by: [e.date, e.description],
        select_merge: %{is_recurrency: not is_nil(r.id)}
      )
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
    |> Enum.filter(& Timex.between?(&1.date, date_start, date_end, inclusive: true))
  end

  defp where_account_in(query, account_ids) do
    from([account: a] in query,
      where: (a.id in ^account_ids) or fragment("?::int = 0", ^length(account_ids))
    )
  end

  def get_recurrency!(id) do
    from(
      r in Recurrency,
      preload: [recurrency_entries: :entry]
    )
    |> Repo.get!(id)
  end

end

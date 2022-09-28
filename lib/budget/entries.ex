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

  def update_entry(%Entry{} = entry, attrs) do
    entry
    |> Entry.changeset(attrs)
    |> Repo.update()
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
    query = 
      from(
        e in Entry,
        where: e.date < ^date,
        select: coalesce(sum(e.value), 0)
      )

    query = 
      if length(accounts_ids) == 0 do
        query
      else
        where(query, [e], e.account_id in ^accounts_ids)
      end

    initials = 
      from(
        a in Account, 
        select: coalesce(sum(a.initial_balance), 0)
      )

    initials = 
      if length(accounts_ids) == 0 do
        initials
      else
        where(initials, [a], a.id in ^accounts_ids)
      end

    Decimal.add(Repo.one(query), Repo.one(initials))
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
        preload: [account: a],
        order_by: [e.date, e.description]
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
    |> Enum.filter(& Timex.between?(&1.date, date_start, date_end))
  end

  defp where_account_in(query, account_ids) do
    from([account: a] in query,
      where: (a.id in ^account_ids) or fragment("?::int = 0", ^length(account_ids))
    )
  end

end

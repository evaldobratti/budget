defmodule Budget.Entries do
  alias Budget.Repo

  import Ecto.Query

  alias Budget.Entries.{
    Account,
    Entry
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
  def delete_account(%Account{} = account) do
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

  def list_entriess_from_accounts(accounts_ids, start_date, end_date) do
    query = 
      from(
        e in Entry,
        where: e.date >= ^start_date and e.date <= ^end_date,
        left_join: a in assoc(e, :account),
        preload: [account: a],
        order_by: [e.date, e.description]
      )

    query = 
      if length(accounts_ids) == 0 do
        query
      else
        where(query, [e], e.account_id in ^accounts_ids)
      end

    Repo.all(query)
  end

  def get_entry!(id) do
    Repo.get(Entry, id)
  end

end

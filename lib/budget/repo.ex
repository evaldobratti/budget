defmodule Budget.Repo do
  use Ecto.Repo,
    otp_app: :budget,
    adapter: Ecto.Adapters.Postgres

  require Ecto.Query

  @tenant_key {__MODULE__, :user_id}

  @impl true
  def prepare_query(_operation, query, opts) do
    cond do
      opts[:skip_user_id] || opts[:schema_migration] ->
        {query, opts}

      user_id = opts[:user_id] ->
        {
          Ecto.Query.where(query, user_id: ^user_id), 
          opts
        }

      true ->
        raise "expected user_id or skip_user_id to be set"
        
    end
  end

  def put_user_id(user_id) do
    Process.put(@tenant_key, user_id)
  end

  def get_user_id() do
    Process.get(@tenant_key)
  end

  @impl true
  def default_options(_operation) do
    [user_id: get_user_id()]
  end

  def add_user_id(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.put_change(changeset, :user_id, get_user_id())
  end

  def add_user_id(map) do
    Map.put(map, :user_id, get_user_id())
  end
end

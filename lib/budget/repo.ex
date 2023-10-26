defmodule Budget.Repo do
  use Ecto.Repo,
    otp_app: :budget,
    adapter: Ecto.Adapters.Postgres

  require Ecto.Query

  @tenant_key {__MODULE__, :profile_id}

  @impl true
  def prepare_query(_operation, query, opts) do
    cond do
      opts[:skip_profile_id] || opts[:schema_migration] ->
        {query, opts}

      profile_id = opts[:profile_id] ->
        {
          Ecto.Query.where(query, profile_id: ^profile_id),
          opts
        }

      true ->
        raise "expected profile_id or skip_profile_id to be set"

    end
  end

  def put_profile_id(profile_id) do
    Process.put(@tenant_key, profile_id)
  end

  def get_profile_id() do
    Process.get(@tenant_key)
  end

  @impl true
  def default_options(_operation) do
    [profile_id: get_profile_id()]
  end

  def add_profile_id(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.put_change(changeset, :profile_id, get_profile_id())
  end

  def add_profile_id(map) do
    Map.put(map, :profile_id, get_profile_id())
  end
end

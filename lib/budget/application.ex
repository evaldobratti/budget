defmodule Budget.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BudgetWeb.Telemetry,
      Budget.Repo,
      {DNSCluster, query: Application.get_env(:budget, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Budget.PubSub},
      # Start a worker by calling: Budget.Worker.start_link(arg)
      # {Budget.Worker, arg},
      # Start to serve requests, typically the last entry
      BudgetWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Budget.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BudgetWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

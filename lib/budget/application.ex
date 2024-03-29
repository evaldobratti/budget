defmodule Budget.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      BudgetWeb.Telemetry,
      # Start the Ecto repository
      Budget.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Budget.PubSub},
      # Start Finch
      {Finch, name: Budget.Finch},
      # Start the Endpoint (http/https)
      BudgetWeb.Endpoint,
      # Start a worker by calling: Budget.Worker.start_link(arg)
      # {Budget.Worker, arg}

      {Registry, keys: :unique, name: Buget.Importer.Registry},
      {DynamicSupervisor, name: Budget.Importer}
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

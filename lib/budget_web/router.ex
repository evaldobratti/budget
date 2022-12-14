defmodule BudgetWeb.Router do
  use BudgetWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {BudgetWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BudgetWeb do
    pipe_through :browser

    live "/", BudgetLive.Index, :index
    live "/accounts/new", BudgetLive.Index, :new_account
    live "/accounts/:id/edit", BudgetLive.Index, :edit_account
    live "/entries/new", BudgetLive.Index, :new_entry
    live "/entries/:id/edit", BudgetLive.Index, :edit_entry
    live "/entries/:id/delete", BudgetLive.Index, :delete_entry
    live "/categories/new", BudgetLive.Index, :new_category
    live "/categories/:id/edit", BudgetLive.Index, :edit_category
    live "/categories/:id/children/new", BudgetLive.Index, :new_category_child

    live "/accounts", AccountLive.Index, :index
    # live "/accounts/new", AccountLive.Index, :new
    # live "/accounts/:id/edit", AccountLive.Index, :edit

    live "/accounts/:id", AccountLive.Show, :show
    live "/accounts/:id/show/edit", AccountLive.Show, :edit
  end

  # Other scopes may use custom stacks.
  # scope "/api", BudgetWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BudgetWeb.Telemetry
    end
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

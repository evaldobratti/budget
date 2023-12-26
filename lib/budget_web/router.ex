defmodule BudgetWeb.Router do
  use BudgetWeb, :router

  import BudgetWeb.GoogleAuthController, only: [check_login: 2]

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {BudgetWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :secure do
    plug :check_login
  end

  scope "/", BudgetWeb do
    pipe_through(:browser)

    get "/login", GoogleAuthController, :login
    get "/auth/google/callback", GoogleAuthController, :signin
    get "/logout", GoogleAuthController, :logout

    live_session :authenticated,
      on_mount: [
        BudgetWeb.Nav
      ] do
      pipe_through :secure

      live "/", BudgetLive.Index, :index

      live "/accounts/new", BudgetLive.Index, :new_account
      live "/accounts/:id/edit", BudgetLive.Index, :edit_account

      live "/categories/new", BudgetLive.Index, :new_category
      live "/categories/:id/edit", BudgetLive.Index, :edit_category
      live "/categories/:id/children/new", BudgetLive.Index, :new_category_child

      live "/transactions/new", BudgetLive.Index, :new_transaction
      live "/transactions/:id/edit", BudgetLive.Index, :edit_transaction
      live "/transactions/:id/delete", BudgetLive.Index, :delete_transaction

      live "/imports", ImportLive.Index, :index
      live "/imports/credit_card/nu_bank", ImportLive.CreditCard.NuBank, :index
      live "/imports/:id", ImportLive.Result, :index

      live "/charts", ChartLive.Index, :index
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", BudgetWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:budget, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: BudgetWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end

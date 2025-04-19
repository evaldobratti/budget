defmodule BudgetWeb.ImportLive.Index do
  use BudgetWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
    }
  end

  def handle_event("parse", %{"json" => json}, socket) do
    IO.inspect(json)

    {:noreply, socket}
  end

end

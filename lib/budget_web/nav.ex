defmodule BudgetWeb.Nav do
  use Phoenix.LiveView

  def render(_assigns), do: nil

  def on_mount(:default, _params, %{"profile" => profile}, socket) do
    {
      :cont,
      socket
      |> attach_hook(:active_tab, :handle_params, &set_active_tab/3)
      |> assign(user: profile)
    }
  end

  defp set_active_tab(_params, _url, socket) do
    active_tab =
      case {socket.view, socket.assigns.live_action} do
        {BudgetWeb.BudgetLive.Index, _} ->
          :transactions

        {BudgetWeb.ImportLive.Index, _} ->
          :import

        {BudgetWeb.ImportLive.Result, _} ->
          :import

        {BudgetWeb.ChartLive.Index, _} ->
          :charts

        {_, _} ->
          nil
      end

    {:cont, assign(socket, active_tab: active_tab)}
  end

end

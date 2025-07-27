defmodule BudgetWeb.Nav do
  use Phoenix.LiveView

  alias Budget.Users

  def render(_assigns), do: nil

  def on_mount(
        :default,
        _params,
        %{"user_id" => user_id, "active_profile_id" => profile_id},
        socket
      ) do
    Budget.Repo.put_profile_id(profile_id)

    user = Users.get_user(user_id)

    profile = Enum.find(user.profiles, &(&1.id == profile_id))

    {
      :cont,
      socket
      |> attach_hook(:active_tab, :handle_params, &set_active_tab/3)
      |> assign(user: user)
      |> assign(active_profile: profile)
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

        {BudgetWeb.ManagementLive.Index, _} ->
          :management

        {_, _} ->
          nil
      end

    {:cont, assign(socket, active_tab: active_tab)}
  end
end

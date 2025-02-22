defmodule BudgetWeb.UserLive.ProfileToggle do
  use BudgetWeb, :live_component

  alias Budget.Users
  alias Budget.Users.Profile

  def mount(socket) do
    socket =
      socket
      |> assign(add_new_profile: false)

    {:ok, socket}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(user: assigns.user)
      |> assign(active_profile: assigns.active_profile)
      |> assign(new_profile_form: to_form(Profile.changeset(%Profile{user_id: assigns.user.id}, %{})) )


    {:ok, socket}
  end

  def other_profiles(user, active_profile) do
    Enum.filter(user.profiles, & &1.id != active_profile.id)
  end

  def handle_event("profile-validate", %{"profile" => profile_params}, socket) do
    changeset =
      %Profile{user_id: socket.assigns.user.id}
      |> Profile.changeset(profile_params)
      |> Map.put(:action, :validate)

    {
      :noreply, 
      socket
      |> assign(new_profile_form: to_form(changeset))
    }
  end

  def handle_event("profile-save", %{"profile" => profile_params}, socket) do
    result =
      %Profile{user_id: socket.assigns.user.id}
      |> Profile.changeset(profile_params)
      |> Users.create_profile()

    
    case result do
      {:ok, profile} ->
        {
          :noreply,
          socket
          |> redirect(to: ~p"/change-profile?#{%{"profile-id" => profile.id}}")
        }

      _ ->
        {
          :noreply, 
          socket
        }
    end
  end

  def handle_event("add-new", _params, socket) do
    socket =
      socket
      |> assign(add_new_profile: true)

    {:noreply, socket}
  end
end

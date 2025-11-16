defmodule BudgetWeb.Transactions.CategoriesList do
  alias Budget.Transactions
  use BudgetWeb, :live_component

  alias BudgetWeb.Helpers.UrlParams
  alias Budget.Transactions
  alias Budget.Transactions.Category

  def mount(socket) do
    {:ok,
     socket
     |> assign(categories: Transactions.list_categories_arranged())
     |> assign(all_selected: false)}
  end

  def update(assigns, socket) do
    selected_ids = UrlParams.get_categories(Map.get(assigns, :url_params))

    {
      :ok,
      socket
      |> assign(:selected_ids, selected_ids)
    }
  end

  def render(assigns) do
    assigns = Map.put_new(assigns, :url_params, %{})

    ~H"""
    <details class="flex flex-col collapse">
      <summary class="collapse-title p-0 min-h-0 ">
        <div class="flex items-center gap-2">
          Categories

          <div class="tooltip ml-auto" data-tip="Select all">
            <input
              type="checkbox"
              class="checkbox checkbox-xs"
              phx-click="toggle-all-category"
              phx-target={@myself}
              checked={@all_selected}
            />
          </div>
          <.link class="btn btn-xs" patch={~p"/categories/new?#{@url_params}"}>
            New
          </.link>
        </div>
      </summary>
      <div class="collapse-content">
        <%= if Enum.empty?(@categories) do %>
          <div class="flex mt-2 flex-justify-center">
            No categories yet
          </div>
        <% end %>
        <div class="max-h-full overflow-y-auto flex flex-col gap-1 mt-1">
          {render_categories(@categories, @selected_ids, @myself)}
        </div>
      </div>
    </details>
    """
  end

  def render_categories(categories, selected_ids, myself) do
    assigns = %{
      categories: categories,
      selected_ids: selected_ids,
      myself: myself
    }

    ~H"""
    <%= for {category, children} <- @categories do %>
      <div class="flex items-center" data-testid={"category-#{category.id}"}>
        <div class="flex items-center gap-1">
          {if length(category.path) > 0, do: "└ "}
          <input
            type="checkbox"
            class="checkbox checkbox-xs"
            phx-click="toggle-category"
            phx-value-category-id={category.id}
            phx-target={@myself}
            checked={category.id in @selected_ids}
          />
          <.link patch={~p"/categories/#{category}/edit"}>
            {category.name}
          </.link>
        </div>
        <div class="ml-auto flex items-center">
          <.link patch={~p"/categories/#{category}/children/new"} class="btn btn-xs">+</.link>
          <%= if category.transactions_count == 0 do %>
            <.link patch={~p"/categories/#{category}/delete"} class="btn btn-xs">
              -
            </.link>
          <% else %>
            <div class="tooltip" data-tip="You cannot delete this category because it has transactions associated.">
              <div class="w-[24.34px] flex justify-center">
                <.icon name="hero-exclamation-circle" />
              </div>
            </div>
          <% end %>
        </div>
      </div>
      <div :if={length(children) > 0} class="pl-1 ml-3 flex flex-col gap-1">
        {render_categories(children, @selected_ids, @myself)}
      </div>
    <% end %>
    """
  end

  def handle_event("toggle-category", %{"category-id" => category_id} = params, socket) do
    {category_id, _} = Integer.parse(category_id)

    category_ids =
      socket.assigns.categories
      |> Category.find_in_tree(category_id)
      |> Category.get_subtree_ids()

    selected_ids =
      if Map.get(params, "value") == "on" do
        Enum.concat(category_ids, socket.assigns.selected_ids)
      else
        Enum.filter(socket.assigns.selected_ids, &(&1 not in category_ids))
      end
      |> Enum.uniq()

    send(self(), {:category_selected_ids, selected_ids})

    {
      :noreply,
      socket
    }
  end

  def handle_event("toggle-all-category", _params, socket) do
    if socket.assigns.all_selected do
      send(self(), {:category_selected_ids, []})
    else
      all_ids =
        Transactions.list_categories()
        |> Enum.map(& &1.id)

      send(self(), {:category_selected_ids, all_ids})
    end

    {
      :noreply,
      socket
      |> assign(all_selected: not socket.assigns.all_selected)
    }
  end
end

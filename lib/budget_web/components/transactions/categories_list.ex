defmodule BudgetWeb.Transactions.CategoriesList do
  alias Budget.Transactions
  use BudgetWeb, :live_component

  alias Budget.Transactions.Category

  def mount(socket) do
    {:ok,
     socket
     |> assign(all_selected: false)}
  end

  def render(assigns) do
    assigns = Map.put_new(assigns, :url_params, %{})

    ~H"""
    <div class="flex flex-col mt-2 overflow-y-auto">
      <div class="flex items-start mt-2">

        <input 
          type="checkbox" 
          phx-click="toggle-all-category" 
          phx-target={@myself}
          checked={@all_selected} 
        />
        Categories
        <.link_button small class="ml-auto px-4 text-center" patch={~p"/categories/new?#{@url_params}"}>New</.link_button>
      </div>
      <%= if Enum.empty?(@categories) do %>
        <div class="flex mt-2 flex-justify-center">
          No categories yet
        </div>
      <% end %>
      <div class="max-h-full overflow-y-auto">
        <%= render_categories(@categories, @category_selected_ids, @myself) %>
      </div>
    </div>
    """
  end

  def render_categories(categories, category_selected_ids, myself) do
    assigns = %{
      categories: categories,
      category_selected_ids: category_selected_ids,
      myself: myself
    }

    ~H"""
    <%= for {category, children} <- @categories do %>
      <div class="flex mt-2">
        <div>
          <%= if length(category.path) > 0, do: "└ " %> 
          <input 
            type="checkbox" 
            phx-click="toggle-category" 
            phx-value-category-id={category.id} 
            phx-target={@myself}
            checked={category.id in @category_selected_ids} 
          />
          <.link patch={~p"/categories/#{category}/edit"}>
            <%= category.name %>
          </.link>
        </div>
        <div class="ml-auto">
          <.link_button patch={~p"/categories/#{category}/children/new"} small class="px-2">+</.link_button>
          <%= if category.transactions_count == 0 do %>
            <%!-- <.link_button patch={~p"/categories/#{category}/delete"} small color="danger" class="px-2">-</.link_button> --%>
          <% else %>
            <.tooltiped id={"not-delete-#{category.id}"} tooltip="You cannot delete this category because it has transactions associated.">
              <.icon name="hero-exclamation-circle" />
            </.tooltiped>
          <% end %>
        </div>

      </div>
      <div :if={length(children) > 0} class="pl-1 ml-3">
        <%= render_categories(children, @category_selected_ids, @myself) %>
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

    category_selected_ids =
      if Map.get(params, "value") == "on" do
        Enum.concat(category_ids, socket.assigns.category_selected_ids)
      else
        Enum.filter(socket.assigns.category_selected_ids, &(&1 not in category_ids))
      end
      |> Enum.uniq()

    send(self(), {:category_selected_ids, category_selected_ids})

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

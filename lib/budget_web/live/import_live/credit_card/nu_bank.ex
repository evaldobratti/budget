defmodule BudgetWeb.ImportLive.CreditCard.NuBank do
  use BudgetWeb, :live_view

  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:uploaded_files, [])
      |> allow_upload(:invoice, accept: ~w(.pdf), max_entries: 1)
    }
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save", _params, socket) do
    [file] =
      consume_uploaded_entries(socket, :invoice, fn %{path: path}, _entry ->
        dest = Path.join([:code.priv_dir(:budget), "static", "uploads", Path.basename(path)])
        # The `static/uploads` directory must exist for `File.cp!/2`
        # and MyAppWeb.static_paths/0 should contain uploads to work,.
        File.cp!(path, dest)

        {:ok, dest}
      end)


    {:ok, key} = 
      Path.join([
        :code.priv_dir(:budget), 
        "static", 
        "uploads", 
        file |> Path.basename()
      ])
      |> Budget.Importations.import()

    {:noreply, push_navigate(socket, to: "/imports/result/" <> key)}
  end
end

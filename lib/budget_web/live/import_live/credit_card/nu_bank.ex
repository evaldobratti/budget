defmodule BudgetWeb.ImportLive.CreditCard.NuBank do
  alias Budget.Importations
  use BudgetWeb, :live_view

  def mount(_params, _session, socket) do
    File.mkdir([:code.priv_dir(:budget), "/static", "/uploads"])
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

    path =
      Path.join([
        :code.priv_dir(:budget),
        "static",
        "uploads",
        file |> Path.basename()
      ])

    {:ok, file} = Importations.create_import_file(path)

    {:noreply, push_navigate(socket, to: ~p"/imports/" <> to_string(file.id))}
  end
end

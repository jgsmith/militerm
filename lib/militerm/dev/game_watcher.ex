defmodule Militerm.Dev.GameWatcher do
  use GenServer

  alias Militerm.Services.{Archetypes, Mixins, Socials, Verbs}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def child_spec(opts \\ []) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def init(opts) do
    path = Militerm.Config.game_dir() |> resolve_symlinks()
    {:ok, watcher_pid} = FileSystem.start_link([{:dirs, [path]} | opts])
    FileSystem.subscribe(watcher_pid)
    {:ok, %{watcher_pid: watcher_pid, root: path}}
  end

  def handle_info(
        {:file_event, watcher_pid, {path, events}},
        %{watcher_pid: watcher_pid, root: root} = state
      ) do
    handle_file_update(root, Path.relative_to(path, root))
    {:noreply, state}
  end

  # we don't handle anything not relative to the game root directory
  def handle_file_update(_, <<"/", _::binary>>), do: :ok

  def handle_file_update(root, path) when is_binary(path) do
    handle_file_update(root, Path.split(Path.rootname(path)), Path.extname(path))
  end

  def handle_file_update(_root, ["std", "archetypes" | bits], ".mt") do
    Archetypes.reload(Enum.join(["std" | bits], ":"))
  end

  def handle_file_update(_root, ["domains", domain, "archetypes" | bits], ".mt") do
    Archetypes.reload(Enum.join([domain | bits], ":"))
  end

  def handle_file_update(_root, ["domains", domain, "areas", area, "scenes" | bits], ".mt") do
    Archetypes.reload(Enum.join(["scene", domain, area | bits], ":"))
  end

  def handle_file_update(_root, ["std", "traits" | bits], ".mt") do
    Mixins.reload(Enum.join(["std" | bits], ":"))
  end

  def handle_file_update(_root, ["domains", domain, "traits" | bits], ".mt") do
    Mixins.reload(Enum.join([domain | bits], ":"))
  end

  def handle_file_update(root, ["socials" | _] = path, ".yaml") do
    Socials.reload_file(Path.join([root | path]) <> ".yaml")
  end

  def handle_file_update(root, ["verbs", _, _] = path, ".md") do
    Verbs.reload_file(Path.join([root | path]) <> ".md")
  end

  def handle_file_update(_, _, _), do: :ok

  def resolve_symlinks(path) do
    # follows symlinks if we can so we don't have them in the end
    path
    |> Path.split()
    |> Enum.reduce("/", fn slug, root ->
      root_slug = root |> Path.join(slug) |> Path.expand()

      case File.lstat(root_slug) do
        {:ok, %{type: :symlink}} ->
          case File.read_link(root_slug) do
            {:ok, new_path} -> Path.expand(new_path, root)
            _ -> root_slug
          end

        _ ->
          root_slug
      end
    end)
  end
end

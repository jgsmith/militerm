defmodule Militerm.Services.Archetypes do
  use Militerm.ECS.CachedService

  alias Militerm.Config
  alias Militerm.Services.Mixins

  @moduledoc """
  The archetype component manages all of the information needed to use archetypes. It's
  relatively read-only for now, with archetypes being read from files.

  We can add support for database-based tweaks later based on hospitals.
  """

  def list_archetypes() do
    base = Config.game_dir() <> "/"

    "#{base}**/archetypes/**/*.mt"
    |> Path.wildcard()
    |> Enum.map(fn path ->
      [domain, arch] =
        path
        |> String.replace_prefix(base, "")
        |> String.replace_suffix(".mt", "")
        |> String.split("/archetypes/", parts: 2)

      domain <> ":" <> Enum.join(String.split(arch, "/", trim: true), ":")
    end)
  end

  def get(ur_name, sub_name) do
    case resolve(ur_name, sub_name) do
      {:ok, name} ->
        Militerm.ECS.CachedService.get(__MODULE__, name, %{})

      _ ->
        %{}
    end
  end

  def get(ur_name) do
    case resolve(ur_name) do
      {:ok, name} ->
        Militerm.ECS.CachedService.get(__MODULE__, name, %{})

      _ ->
        %{}
    end
  end

  def set(_, _), do: {:error, "Changes not supported"}

  ###
  ### Persistance
  ###

  @impl true
  def store(ur_name, data) do
    # does nothing -
  end

  @impl true
  def update(ur_name, old_data, new_data) do
    # does nothing
  end

  @impl true
  def fetch(ur_name) do
    # tries to find the file and parse it
    # the ur_name is a colon-separated list of directories, etc.
    case do_load(ur_name) do
      %{} = result -> result
      otherwise -> nil
    end
  end

  @impl true
  def delete(entity_id) do
    # does nothing
  end

  @impl true
  def clear() do
    # does nothing
  end

  @spec resolve(String.t(), String.t()) :: {:ok | :error, String.t()}
  def resolve(<<"std:", _>> = name, _), do: resolve(name)
  # if ur_name doesn't resolve to something, then we look
  # relative to sub_name
  # std:foo => std:foo
  # foo % start:inn:yard => start:inn:foo or start:foo or std:foo

  def resolve(ur_name, sub_name) do
    Militerm.Util.File.resolve("archetypes", ur_name, sub_name)
  end

  def resolve(<<"std:", ur_name::binary>>) do
    {
      :ok,
      "std:" <>
        (ur_name
         |> String.split(":")
         |> Militerm.Util.File.clean_path()
         |> Enum.join(":"))
    }
  end

  def resolve(ur_name), do: resolve("", ur_name)

  defp do_load(name) do
    name
    |> String.split(":")
    |> file_for_path
    |> load_content
    |> parse(name)
    |> compile(name)
  end

  defp file_for_path(["std" | bits]) do
    [
      Config.game_dir()
      | [
          "std/archetypes"
          | bits |> Militerm.Util.File.clean_path()
        ]
    ]
    |> Enum.join("/")
  end

  defp file_for_path([domain | bits]) do
    ([Config.game_dir()] ++
       ["domains" | domain |> String.split("/") |> Militerm.Util.File.clean_path()] ++
       ["archetypes" | bits |> Militerm.Util.File.clean_path()])
    |> Enum.join("/")
  end

  defp load_content(filename), do: File.read(filename <> ".mt")

  defp parse({:error, _} = error, _), do: error

  defp parse(content, name) do
    case Militerm.Parsers.Script.parse(:archetype, content) do
      %{errors: [_ | _] = errors} ->
        error_strings =
          errors
          |> Enum.map(fn {message, {line, _}, _} -> "Line #{line}: #{message}" end)

        raise "Errors loading #{name}:\n#{Enum.join(error_strings, "\n")}"

      otherwise ->
        otherwise
    end
  end

  defp compile({:error, _} = error, _), do: error

  defp compile(parse, name) do
    parse
    |> find_mixins(name)
    |> gather_data()
    |> compile_reactions()
    |> compile_abilities()
    |> compile_functions(:calculations)
    |> compile_functions(:traits)
    |> compile_functions(:validators)
    |> Map.put(:name, name)
  end

  defp compile_reactions(%{reactions: reactions} = parse) do
    compiled =
      reactions
      |> Enum.map(fn {{path, role}, ast} ->
        rpath = path |> String.split(":", trim: true) |> Enum.reverse()
        {{rpath, role}, Militerm.Compilers.Script.compile(ast)}
      end)
      |> Enum.into(%{})

    %{parse | reactions: compiled}
  end

  defp compile_abilities(%{abilities: abilities} = parse) do
    compiled =
      abilities
      |> Enum.map(fn {{path, role}, ast} ->
        rpath = path |> String.split(":", trim: true) |> Enum.reverse()
        {{rpath, role}, Militerm.Compilers.Script.compile(ast)}
      end)
      |> Enum.into(%{})

    %{parse | abilities: compiled}
  end

  defp compile_functions(parse, field) do
    compiled =
      parse
      |> Map.get(field)
      |> Enum.map(fn {key, ast} ->
        {key, Militerm.Compilers.Script.compile(ast)}
      end)
      |> Enum.into(%{})

    Map.put(parse, field, compiled)
  end

  defp find_mixins(%{mixins: mixins, traits: traits} = parse, ur) do
    # if the mixin resolves to a mixin, then it's a mixin - otherwise, it's a trait
    {mixins, traits} =
      mixins
      |> Enum.reduce({[], traits}, fn mixin, {resolved, traits} ->
        case Mixins.resolve(mixin, ur) do
          {:ok, resolved_name} ->
            {[resolved_name | resolved], traits}

          _ ->
            {resolved, [{mixin, {:const, "True"}} | traits]}
        end
      end)

    %{parse | mixins: mixins, traits: traits}
  end

  defp gather_data(%{mixins: mixins, ur_name: nil, data: data} = parse) do
    gathered_data =
      mixins
      |> Enum.reduce(%{}, fn mixin, acc ->
        case Mixins.get(mixin) do
          %{data: mixin_data} ->
            merge(acc, mixin_data)

          _ ->
            acc
        end
      end)
      |> merge(data)

    %{parse | data: gathered_data}
  end

  defp gather_data(%{mixins: mixins, ur_name: ur_name, data: data} = parse) do
    # get ur_data - then mixin data, then our data
    case get(ur_name) do
      %{data: ur_data} ->
        gathered_data =
          mixins
          |> Enum.reduce(ur_data, fn mixin, acc ->
            case Mixins.get(mixin) do
              %{data: mixin_data} ->
                merge(acc, mixin_data)

              _ ->
                acc
            end
          end)
          |> merge(data)

        %{parse | data: gathered_data}

      _ ->
        parse
    end
  end

  defp merge(map1, map2) when is_map(map1) and is_map(map2) do
    Map.merge(map1, map2, fn _, m1, m2 -> merge(m1, m2) end)
  end

  defp merge(_, value), do: value
end

defmodule Militerm.Services.Mixins do
  use Militerm.ECS.CachedService

  alias Militerm.Config

  @moduledoc """
  The mixin service manages all of the information needed to use mixins. It's
  relatively read-only for now, with mixins being read from files.

  We can add support for database-based tweaks later based on hospitals.
  """

  def get(ur_name, sub_name) do
    with {:ok, name} <- resolve(ur_name, sub_name) do
      Militerm.ECS.CachedService.get(__MODULE__, name, %{})
    else
      _ -> %{}
    end
  end

  def get(ur_name) do
    with {:ok, name} <- resolve(ur_name) do
      Militerm.ECS.CachedService.get(__MODULE__, name, %{})
    else
      _ -> %{}
    end
  end

  def set(_, _), do: {:error, "Changes not supported"}

  ###
  ### Persistance
  ###

  @impl true
  def store(name, data) do
    # does nothing -
  end

  @impl true
  def update(name, old_data, new_data) do
    # does nothing
  end

  @impl true
  def fetch(name) do
    # tries to find the file and parse it
    # the ur_name is a colon-separated list of directories, etc.
    case do_load(name) do
      %{} = result -> result
      otherwise -> nil
    end
  end

  @impl true
  def delete(name) do
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

  def resolve(name, sub_name) do
    Militerm.Util.File.resolve("traits", name, sub_name)
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
          "std/traits"
          | bits |> Militerm.Util.File.clean_path()
        ]
    ]
    |> Enum.join("/")
  end

  defp file_for_path([domain | bits]) do
    ([Config.game_dir()] ++
       ["domains" | domain |> String.split("/") |> Militerm.Util.File.clean_path()] ++
       ["traits" | bits |> Militerm.Util.File.clean_path()])
    |> Enum.join("/")
  end

  defp load_content(filename), do: File.read(filename <> ".mt")

  defp parse({:error, _} = error, _), do: error

  defp parse(content, name) do
    case Militerm.Parsers.Script.parse(:trait, content) do
      %{errors: [_ | _] = errors} ->
        error_strings =
          errors
          |> Enum.map(fn {message, {line, _}, _} -> "Line #{line}: #{message}" end)

        raise "Errors loading #{name}:\n#{Enum.join(error_strings, "\n")}"

      otherwise ->
        otherwise
    end
  end

  defp compile({:error, _} = error), do: error

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
        case resolve(mixin, ur) do
          {:ok, ^ur} ->
            {resolved, [{mixin, {:const, "True"}} | traits]}

          {:ok, resolved_name} ->
            {[resolved_name | resolved], traits}

          _ ->
            {resolved, [{mixin, {:const, "True"}} | traits]}
        end
      end)

    %{parse | mixins: mixins, traits: traits}
  end

  defp gather_data(%{mixins: mixins, data: data} = parse) do
    # get ur_data - then mixin data, then our data
    gathered_data =
      mixins
      |> Enum.reduce(%{}, fn mixin, acc ->
        with %{data: mixin_data} <- get(mixin) do
          merge(acc, mixin_data)
        else
          _ -> acc
        end
      end)
      |> merge(data)

    %{parse | data: gathered_data}
  end

  defp merge(map1, map2) when is_map(map1) and is_map(map2) do
    Map.merge(map1, map2, fn _, m1, m2 -> merge(m1, m2) end)
  end

  defp merge(_, value), do: value
end

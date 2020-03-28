defmodule Militerm.AberToMiliterm do
  @moduledoc """
  Provides utilities to create militerm areas out of Abermud zone files.
  """

  @directions %{
    "n" => "north",
    "e" => "east",
    "s" => "south",
    "w" => "west",
    "u" => "up",
    "d" => "down"
  }

  @doc """
  Translates all of the zone files in dir_path into militerm files.
  """
  def translate(dir_path) do
    dir_path
    |> list_json_files()
    |> Enum.each(&translate_file/1)
  end

  def list_json_files(path) do
    {:ok, files} = File.ls(path)

    files
    |> Enum.filter(&String.ends_with?(&1, ".json"))
    |> Enum.map(&Path.join(path, &1))
  end

  def translate_file(file) do
    file
    |> read_file()
    |> collect_scenes()
    |> write_scenes()
  end

  def read_file(file) do
    {YamlElixir.read_from_file!(file), %{}}
  end

  def write_scenes({_, %{scenes: scenes}} = state) do
    root_dir = Militerm.Config.game_dir()

    scenes
    |> Enum.each(fn {filename, data} ->
      full_file_path = Path.join(root_dir, filename)
      File.mkdir_p!(Path.dirname(full_file_path))
      File.write!(full_file_path, Militerm.Util.Yaml.write_to_string(data))
    end)

    state
  end

  def collect_scenes({json, output}) do
    scenes =
      json
      |> Map.get("loc", %{})
      |> Enum.map(&collect_scene/1)

    {json, Map.put(output, :scenes, scenes)}
  end

  def collect_scene({key, info}) do
    [name, area] = String.split(key, "@", trim: true, parts: 2)

    {"domains/aber/areas/#{area}/scenes/#{name}.yaml",
     %{
       "detail" => %{
         "default" => collect_scene_details(area, info)
       },
       "flag" => collect_scene_flags(info)
     }}
  end

  def collect_scene_details(area, info) do
    %{
      "short" => Map.get(info, "title", ""),
      "sight" => String.replace(String.trim(Map.get(info, "description", "")), "\n", " "),
      "exits" => collect_scene_exits(area, info)
    }
  end

  def collect_scene_exits(area, info) do
    info
    |> Map.get("exits", %{})
    |> Enum.map(&map_scene_exit(area, &1))
    |> Enum.into(%{})
  end

  def map_scene_exit(_, {direction, <<"^", _::binary>>}) do
    {Map.get(@directions, direction), nil}
  end

  def map_scene_exit(area, {direction, target}) do
    target_scene =
      case String.split(String.downcase(target), "@", trim: true, parts: 2) do
        [name, new_area] ->
          "scene:aber:#{new_area}:#{name}"

        [name] ->
          "scene:aber:#{area}:#{name}"
      end

    {Map.get(@directions, direction),
     %{
       "target" => target_scene
     }}
  end

  def collect_scene_flags(info) do
    info
    |> Map.get("flags", [])
    |> Enum.map(&String.downcase/1)
  end
end

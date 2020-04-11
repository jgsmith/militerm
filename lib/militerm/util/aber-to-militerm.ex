defmodule Militerm.Util.AberToMiliterm do
  @moduledoc """
  Provides utilities to create militerm areas out of Abermud zone files.
  """

  alias Militerm.English

  @directions %{
    "n" => "north",
    "e" => "east",
    "s" => "south",
    "w" => "west",
    "u" => "up",
    "d" => "down",
    "ne" => "northeast",
    "nw" => "northwest",
    "se" => "southeast",
    "sw" => "southwest"
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
    |> add_base(file)
    |> add_area(file)
    |> collect_scenes()
    # |> collect_npcs()
    # |> collect_exits()
    |> collect_hospital()
    |> write_files(:scenes)
    # |> write_files(:exits)
    # |> write_files(:npcs)
    |> write_files(:hospital)
  end

  def read_file(file) do
    %{json: YamlElixir.read_from_file!(file)}
    # {YamlElixir.read_from_file!(file), %{}}
  end

  def add_base(info, file) do
    info
    |> Map.put(:base, Path.dirname(file))
  end

  def add_area(info, file) do
    info
    |> Map.put(:area, Path.basename(file, ".json"))
  end

  def read_zone_file(%{base: path}, zone) do
    path
    |> Path.join("#{zone}.json")
    |> YamlElixir.read_from_file!()
  end

  def write_files(state, field) do
    items = Map.get(state, field, [])
    root_dir = Militerm.Config.game_dir()

    items
    |> Enum.each(fn {filename, data} ->
      full_file_path = Path.join(root_dir, filename)
      File.mkdir_p!(Path.dirname(full_file_path))
      File.write!(full_file_path, Militerm.Util.Yaml.write_to_string(data))
    end)

    state
  end

  def collect_scenes(%{json: json} = state) do
    scenes =
      json
      |> Map.get("loc", %{})
      |> Enum.map(&collect_scene(&1, state))

    Map.put(state, :scenes, scenes)
  end

  def collect_scene({key, info}, %{area: area} = state) do
    [name, _] = String.split(key, "@", trim: true, parts: 2)

    {"domains/aber/areas/#{area}/scenes/#{name}.yaml",
     %{
       "detail" => %{
         "default" => collect_scene_details(info, state)
       },
       "flag" => collect_scene_flags(info)
     }}
  end

  def collect_scene_details(info, state) do
    %{
      "short" => Map.get(info, "title", ""),
      "sight" => String.replace(String.trim(Map.get(info, "description", "")), "\n", " "),
      "exits" => collect_scene_exits(info, state)
    }
  end

  def collect_scene_exits(info, state) do
    info
    |> Map.get("exits", %{})
    |> Enum.map(&map_scene_exit(&1, state))
    |> Enum.into(%{})
  end

  def map_scene_exit({direction, <<"^", guard_obj::binary>>}, %{area: area, json: json} = state) do
    case String.split(String.downcase(guard_obj), "@", trim: true, parts: 2) do
      [obj_name] ->
        obj =
          json
          |> Map.get("obj", %{})
          |> Enum.find(fn {name, _} -> String.downcase(name) == "#{obj_name}@#{area}" end)

        case get_linked_exit(obj, state) do
          scene_id when is_binary(scene_id) ->
            {Map.get(@directions, direction),
             %{
               "target" => scene_id,
               "guarded" => true
             }}

          _ ->
            {Map.get(@directions, direction), nil}
        end

      [obj_name, other_area] ->
        other_area_json = read_zone_file(state, other_area)

        obj =
          other_area_json
          |> Map.get("obj", %{})
          |> Enum.find(fn {name, _} -> String.downcase(name) == "#{obj_name}@#{area}" end)

        case get_linked_exit(obj, %{state | json: other_area_json}) do
          scene_id when is_binary(scene_id) ->
            {Map.get(@directions, direction),
             %{
               "target" => scene_id,
               "guarded" => true
             }}

          _ ->
            {Map.get(@directions, direction), nil}
        end

      _ ->
        {Map.get(@directions, direction), nil}
    end
  end

  def map_scene_exit({direction, target}, %{area: area} = state) do
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

  def get_linked_exit({_, %{"linked" => target_obj}}, %{json: json, area: area} = state) do
    case String.split(String.downcase(target_obj), "@", trim: true, parts: 2) do
      # in the same area
      [target_name] ->
        obj =
          json
          |> Map.get("obj", %{})
          |> Enum.find(fn {name, _} -> String.downcase(name) == "#{target_name}@#{area}" end)

        case obj do
          {_, %{"location" => <<"IN_ROOM:", target::binary>>}} ->
            get_scene_entity_id(target, state)

          _ ->
            nil
        end

      [target_name, target_area] ->
        target_json = read_zone_file(state, target_area)

        obj =
          target_json
          |> Map.get("obj", %{})
          |> Enum.find(fn {name, _} ->
            String.downcase(name) == "#{target_name}@#{target_area}"
          end)

        case obj do
          {_, %{"location" => <<"IN_ROOM:", target::binary>>}} ->
            get_scene_entity_id(target, state)

          _ ->
            nil
        end
    end
  end

  def get_linked_exit(_, _), do: nil

  def get_scene_entity_id(target, %{area: area} = state) do
    case String.split(String.downcase(target), "@", trim: true, parts: 2) do
      [name, new_area] ->
        "scene:aber:#{new_area}:#{name}"

      [name] ->
        "scene:aber:#{area}:#{name}"
    end
  end

  def collect_scene_flags(info) do
    info
    |> Map.get("flags", [])
    |> Enum.map(&normalize_flag/1)
  end

  def collect_exits(%{json: json} = state) do
    exits =
      json
      |> Map.get("loc", %{})
      |> Enum.flat_map(&collect_exits_for_scene(&1, state))

    name =
      json
      |> Map.get("loc", %{})
      |> Map.keys()
      |> List.first()

    [_, area] =
      name
      |> String.split("@", trim: true, parts: 2)
      |> String.downcase()

    exit_filename = "domains/aber/areas/#{area}/exits.yaml"

    Map.put(state, :exits, [{exit_filename, exits}])
  end

  def collect_exits_for_scene({_, scene}, state) do
    []
  end

  def collect_npcs(%{json: json} = state) do
    npcs =
      json
      |> Map.get("mob", %{})
      |> Enum.map(&collect_npc(&1, state))

    Map.put(state, :npcs, npcs)
  end

  def collect_npc({key, info}, state) do
    [name, _] = String.split(key, "@", trim: true, parts: 2)

    sflags = as_list(Map.get(info, "sflags", []))

    {nominative, objective, possessive} =
      if "Female" in sflags do
        {"she", "her", "her"}
      else
        {"he", "him", "his"}
      end

    # {"domains/aber/areas/#{area}/npcs/#{name}.yaml",
    %{
      # "archetype" => "aber:npc",
      "detail" => %{
        "default" => collect_npc_details(info, state)
      },
      "flag" => collect_npc_flags(info),
      "identity" => %{
        "name" => Map.get(info, "pname", Map.get(info, "name", "")),
        "nominative" => nominative,
        "objective" => objective,
        "possessive" => possessive
      }
    }

    # }
  end

  def collect_npc_details(info, %{area: area} = state) do
    %{
      "short" => Map.get(info, "pname", Map.get(info, "name", "")),
      "sight" => String.replace(String.trim(Map.get(info, "description", "")), "\n", " "),
      "nouns" => collect_npc_nouns(info)
    }
  end

  def as_list(binary) when is_binary(binary), do: []
  def as_list(list), do: list

  def collect_npc_flags(info) do
    raw_flags = as_list(Map.get(info, "eflags", [])) ++ as_list(Map.get(info, "pflags", []))

    raw_flags
    |> Enum.map(&normalize_flag/1)
    |> Enum.uniq()
  end

  def collect_npc_nouns(info) do
    pname =
      info
      |> Map.get("pname", "")
      |> String.downcase()
      |> English.remove_article()

    name =
      info
      |> Map.get("name", "")
      |> String.downcase()
      |> English.remove_article()
      |> String.replace(~r{\d+$}, "")

    [pname, name]
    |> Enum.uniq()
    |> Enum.reject(&is_blank/1)
  end

  def collect_hospital(%{json: json, area: area} = state) do
    npcs =
      json
      |> Map.get("mob", %{})
      |> Enum.to_list()

    if Enum.any?(npcs) do
      hospital = [
        {"domains/aber/areas/#{area}/hospital.yaml",
         %{
           "npcs" => collect_hospital_npcs(npcs, state),
           "groups" => collect_hospital_groups(npcs),
           "locations" => collect_hospital_locations(npcs)
         }}
      ]

      Map.put(state, :hospital, hospital)
    else
      state
    end
  end

  def collect_hospital_npcs(npcs, state) do
    npcs
    |> Enum.map(fn {key, info} ->
      [name, area] = String.split(key, "@", parts: 2, trim: true)

      {name,
       %{
         "archetype" => "aber:npc",
         "is_unique" => true,
         "data" => collect_npc({key, info}, state)
       }}
    end)
    |> Enum.into(%{})
  end

  def collect_hospital_locations(npcs) do
    npcs
    |> Enum.map(fn {key, info} ->
      [name, area] = String.split(String.downcase(key), "@", parts: 2, trim: true)
      {name, String.downcase(Map.get(info, "location", ""))}
    end)
    |> Enum.group_by(&elem(&1, 1))
    |> Enum.map(fn {loc, list} ->
      case list do
        [] ->
          nil

        [{name, _}] ->
          {loc,
           %{
             "npcs" => %{name => 1}
             # list
             # |> Enum.map(fn {name, _} -> {name, 1} end)
             # |> Enum.into(%{})
             #   %{
             #     "name" => name
             #   }
             # end)
           }}

        _ ->
          {loc, %{"groups" => %{loc => 1}}}
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.into(%{})
  end

  def collect_hospital_groups(npcs) do
    npcs
    |> Enum.map(fn {key, info} ->
      [name, area] = String.split(String.downcase(key), "@", parts: 2, trim: true)
      {name, String.downcase(Map.get(info, "location", ""))}
    end)
    |> Enum.group_by(&elem(&1, 1))
    |> Enum.map(fn {loc, list} ->
      case list do
        [] ->
          nil

        [_] ->
          nil

        _ ->
          {loc,
           %{
             "npcs" =>
               list
               |> Enum.map(fn {name, _} -> {name, 1} end)
               |> Enum.into(%{})
           }}
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.into(%{})
  end

  def normalize_flag(string) do
    string
    |> String.replace(~r{[A-Z]}, &"-#{&1}")
    |> String.trim_leading("-")
    |> String.downcase()
  end

  def is_blank(""), do: true
  def is_blank(nil), do: true
  def is_blank(_), do: false
end

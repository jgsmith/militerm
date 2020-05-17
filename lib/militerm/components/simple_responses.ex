defmodule Militerm.Components.SimpleResponses do
  use Militerm.ECS.EctoComponent, default: %{}, schema: Militerm.Data.SimpleResponses

  @moduledoc """
  SimpleResponses are patterns that can trigger events when matched against
  a text.

  For now, these patterns are stored as original source text in the database
  and compiled into regexes when loaded.
  """

  def set_value(entity_id, path, value) do
    set_raw_value(entity_id, path, value)
  end

  def get_value(entity_id, path) do
    get_raw_value(entity_id, path)
  end

  def remove_value(entity_id, path) do
    spath = Enum.join(path, ":")

    update(entity_id, fn
      nil -> nil
      map -> Map.delete(map, path)
    end)
  end

  def set_raw_value(entity_id, path, value) when is_list(path) do
    # set_raw_value(entity_id, Enum.join(path, ":"), value)
  end

  def set_raw_value(entity_id, path, value) do
    # update(entity_id, fn
    #   nil -> %{path => value}
    #   map -> Map.put(map, path, value)
    # end)
  end

  def get_raw_value(entity_id, path) when is_list(path) do
    get_raw_value(entity_id, Enum.join(path, ":"))
  end

  def get_raw_value(entity_id, []) do
    case get(entity_id) do
      %{} = map -> Map.keys(map)
      _ -> []
    end
  end

  def get_raw_value(entity_id, [set]) do
    case get(entity_id) do
      %{} = map -> Map.get(set, [])
      _ -> []
    end
  end

  def get_raw_value(entity_id, [set, key]) do
    list = get_raw_value(entity_id, [set])

    case key do
      "count" ->
        Enum.count(list)

      index when is_integer(index) ->
        Map.take(Enum.at(list, index, %{}), ~w[pattern event])
    end
  end

  def get_raw_value(entity_id, [set, index, key])
      when is_integer(index) and key in ~w[pattern event] do
    case get(entity_id) do
      nil ->
        nil

      map ->
        map
        |> Map.get(set)
        |> Enum.at(index, %{})
        |> Map.get(key, nil)
    end
  end

  def hibernate(_entity_id), do: :ok
  def unhibernate(_entity_id), do: :ok

  def set(entity_id, data) do
    Militerm.ECS.Component.set(__MODULE__, entity_id, process_record(data))
  end

  def get_set(entity_id, set) do
    case get(entity_id) do
      %{} = map -> Map.get(map, set, [])
      _ -> []
    end
  end

  def write_data(map, data) do
    Map.put(map, :data, remove_regexes(data))
  end

  def process_record(nil), do: %{}

  def process_record(map) do
    map
    |> Enum.map(&add_regexes/1)
    |> Enum.into(%{})
  end

  def remove_regexes(map) when is_map(map) do
    map
    |> Enum.map(&remove_regexes/1)
    |> Enum.into(%{})
  end

  def remove_regexes({set, patterns}) do
    {set, Enum.map(patterns, &Map.drop(&1, ["regex"]))}
  end

  def add_regexes({set, patterns}) do
    {set, Enum.map(patterns, &add_regex/1)}
  end

  def add_regex(%{"pattern" => pattern} = info) do
    if is_list(pattern) do
      Map.put(info, "regex", Enum.map(pattern, &Militerm.Parsers.SimpleResponse.parse/1))
    else
      Map.put(info, "regex", Militerm.Parsers.SimpleResponse.parse(pattern))
    end
  end
end

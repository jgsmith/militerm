defmodule Militerm.Components.Things do
  use Militerm.ECS.EctoComponent, default: %{}, schema: Militerm.Data.Things

  @moduledoc """
  Things are entities that are tracked by an entity. Values can be a single
  entity or a list/set of entites. No support for using paths to select
  individual entities in a set.
  """

  def set_value(entity_id, path, value) do
    set_raw_value(entity_id, path, value)
  end

  def get_value(entity_id, path) do
    get_raw_value(entity_id, path)
  end

  def remove_value(entity_id, path) do
    path_keys = Enum.map(path, &Access.key(&1, %{}))

    update(entity_id, fn
      nil ->
        nil

      map ->
        {_, new_map} = Access.pop(map, path_keys)
        new_map
    end)
  end

  def set_raw_value(entity_id, path, value) when is_binary(path) do
    set_raw_value(entity_id, String.split(path, ":", trim: true), value)
  end

  def set_raw_value(entity_id, path, value) when is_list(path) do
    path_keys = Enum.map(path, &Access.key(&1, %{}))

    update(entity_id, fn
      nil -> put_in(%{}, path_keys, dehydrate(value))
      map -> put_in(map, path_keys, dehydrate(value))
    end)
  end

  def get_raw_value(entity_id, path) when is_binary(path) do
    get_raw_value(entity_id, String.split(path, ":", trim: true))
  end

  def get_raw_value(entity_id, path) when is_list(path) do
    [last_key | rpath] = Enum.reverse(path)

    rpath_keys = Enum.map(rpath, &Access.key(&1, %{}))

    path_keys = Enum.reverse([Access.key(last_key) | rpath_keys])

    case get(entity_id) do
      nil -> nil
      map -> rehydrate(get_in(map, path_keys))
    end
  end

  def hibernate(_entity_id), do: :ok
  def unhibernate(_entity_id), do: :ok

  @doc """
  ## Examples

    iex> Things.dehydrate([{:thing, "foo"}, {:thing, "bar", "baz"}])
    ["foo", %{"entity_id" => "bar", "coord" => "baz"}]
  """
  def dehydrate(list) when is_list(list) do
    Enum.map(list, &dehydrate/1)
  end

  def dehydrate({:thing, entity_id}), do: entity_id
  def dehydrate({:thing, entity_id, coord}), do: %{"entity_id" => entity_id, "coord" => coord}

  @doc """
  ## Examples

    iex> Things.rehydrate(["foo", %{"entity_id" => "bar", "coord" => "baz"}])
    [{:thing, "foo"}, {:thing, "bar", "baz"}]
  """
  def rehydrate(list) when is_list(list) do
    Enum.map(list, &rehydrate/1)
  end

  def rehydrate(%{"entity_id" => entity_id, "coord" => coord}) do
    {:thing, entity_id, coord}
  end

  def rehydrate(entity_id) when is_binary(entity_id) do
    {:thing, entity_id}
  end

  def rehydrate(something) do
    nil
  end
end

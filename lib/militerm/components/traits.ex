defmodule Militerm.Components.Traits do
  use Militerm.ECS.EctoComponent, default: %{}, schema: Militerm.Data.Traits

  @moduledoc """
  Traits are arbitrary scalars that can be associated with an entity.
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
      nil -> put_in(%{}, path_keys, value)
      map -> put_in(map, path_keys, value)
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
      map -> get_in(map, path_keys)
    end
  end

  def hibernate(_entity_id), do: :ok
  def unhibernate(_entity_id), do: :ok
end

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
    spath = Enum.join(path, ":")

    update(entity_id, fn
      nil -> nil
      map -> Map.delete(map, spath)
    end)
  end

  def set_raw_value(entity_id, path, value) when is_list(path) do
    set_raw_value(entity_id, Enum.join(path, ":"), value)
  end

  def set_raw_value(entity_id, path, value) do
    update(entity_id, fn
      nil -> %{path => value}
      map -> Map.put(map, path, value)
    end)
  end

  def get_raw_value(entity_id, path) when is_list(path) do
    get_raw_value(entity_id, Enum.join(path, ":"))
  end

  def get_raw_value(entity_id, path) do
    case get(entity_id) do
      nil -> nil
      map -> Map.get(map, path)
    end
  end

  def hibernate(_entity_id), do: :ok
  def unhibernate(_entity_id), do: :ok
end
defmodule Militerm.Components.EphemeralPad do
  use Militerm.ECS.Component, default: %{}, ephemeral: true

  @moduledoc """
  The ephemeral pad is used during run-time for situations where it isn't appropriate to save across restarts.
  This is useful to coordinate command execution.
  """

  def set_value(entity_id, path, value) do
    set_raw_value(entity_id, path, value)
  end

  def get_value(entity_id, path) do
    get_raw_value(entity_id, path)
  end

  def set_raw_value(entity_id, path, value) do
    update(entity_id, fn
      nil -> %{path => value}
      map -> Map.put(map, path, value)
    end)
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

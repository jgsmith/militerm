defmodule Militerm.Components.Aliases do
  use Militerm.ECS.EctoComponent,
    default: %{},
    schema: Militerm.Data.Aliases

  @moduledoc """
  The aliases component manages command aliases.
  """

  def set(entity_id, word, definition) do
    Militerm.ECS.Component.update(__MODULE__, entity_id, fn
      nil -> %{word => definition}
      map -> Map.put(map, word, definition)
    end)
  end

  def set(entity_id, aliases) when is_map(aliases) do
    Militerm.ECS.Component.set(__MODULE__, entity_id, aliases)
  end

  def remove(entity_id, word) do
    Militerm.ECS.Component.update(__MODULE__, entity_id, fn
      nil ->
        nil

      map ->
        new_map = Map.drop(map, [word])
        if map_size(new_map) == 0, do: nil, else: new_map
    end)
  end

  def remove(entity_id) do
    Militerm.ECS.Component.remove(__MODULE__, entity_id)
  end

  def hibernate(_entity_id), do: :ok
  def unhibernate(_entity_id), do: :ok
end

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
    spath = Enum.join(path, ":")

    update(entity_id, fn
      nil -> nil
      map -> Map.delete(map, path)
    end)
  end

  def set_raw_value(entity_id, path, value) when is_list(path) do
    set_raw_value(entity_id, Enum.join(path, ":"), value)
  end

  def set_raw_value(entity_id, path, value) do
    update(entity_id, fn
      nil -> %{path => dehydrate(value)}
      map -> Map.put(map, path, dehydrate(value))
    end)
  end

  def get_raw_value(entity_id, path) when is_list(path) do
    get_raw_value(entity_id, Enum.join(path, ":"))
  end

  def get_raw_value(entity_id, path) do
    case get(entity_id) do
      nil ->
        nil

      map ->
        map
        |> Map.get(path)
        |> rehydrate
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
end

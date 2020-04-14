defmodule Militerm.Components.Entity do
  use Militerm.ECS.EctoComponent, default: %{}, schema: Militerm.Data.Entity

  @moduledoc """
  The entity component manages all of the information needed to manage entity controllers.
  """

  def get_value(entity_id, path), do: get_raw_value(entity_id, path)

  def get_raw_value(entity_id, ["archetype"]), do: archetype(entity_id)
  def get_raw_value(entity_id, ["hibernated"]), do: hibernated?(entity_id)

  def get_raw_value(_, _), do: nil

  def register(entity_id, module) do
    set(entity_id, %{"module" => to_string(module)})
  end

  def register(entity_id, module, archetype) do
    set(entity_id, %{"module" => to_string(module), "archetype" => archetype})
  end

  def hibernate(entity_id) do
    update(entity_id, fn
      nil -> nil
      info -> Map.put(info, "hibernated", true)
    end)
  end

  def unhibernate(entity_id) do
    update(entity_id, fn
      nil -> nil
      info -> Map.drop(info, ["hibernated"])
    end)
  end

  def hibernated?(entity_id) do
    case get(entity_id) do
      %{"hibernated" => flag} -> flag
      _ -> false
    end
  end

  def set_archetype(entity_id, archetype) do
    update(entity_id, fn
      nil ->
        nil

      %{} = record ->
        Map.put(record, "archetype", archetype)
    end)
  end

  def module(entity_id) do
    case get(entity_id) do
      %{"module" => name} -> {:ok, as_existing_atom(name)}
      %{module: name} -> {:ok, as_existing_atom(name)}
      _ -> {:error, "Module not found"}
    end
  end

  def archetype(entity_id) do
    case get(entity_id) do
      %{"archetype" => name} -> {:ok, name}
      %{archetype: name} -> {:ok, name}
      _ -> {:error, "Archetype not found"}
    end
  end

  def update_components(entity_id, data) do
    for {key, module} <- Militerm.Config.master().components() do
      if Map.has_key?(data, key) do
        module.set(entity_id, Map.get(data, key))
      end
    end

    :ok
  end

  def get_components(entity_id) do
    Militerm.Config.master().components()
    |> Enum.reduce(%{}, fn {key, module}, acc ->
      acc
      |> Map.put(
        key,
        entity_id
        |> module.get()
      )
    end)
  end

  def entity_exists?(entity_id), do: map_size(get(entity_id)) > 0

  def process_record(%{"module" => module} = record) when is_binary(module) do
    %{record | "module" => String.to_existing_atom(module)}
  end

  def process_record(record), do: record

  def as_existing_atom(atom) when is_atom(atom), do: atom

  def as_existing_atom(string) when is_binary(string) do
    String.to_existing_atom(string)
  end
end

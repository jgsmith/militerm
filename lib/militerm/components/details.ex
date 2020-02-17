defmodule Militerm.Components.Details do
  use Militerm.ECS.EctoComponent, default: %{}, schema: Militerm.Data.Detail

  import Ecto.Query

  @moduledoc """
  The detail component manages all of the information needed to describe the entity to a
  player.

  An entity has a number of details. The "default" detail is considered the root that is
  given when no detail is specified.
  """

  def get_value(entity_id, path, _args), do: get_raw_value(entity_id, path)

  def set_value(entity_id, path, value, _args), do: set_raw_value(entity_id, path, value)

  def set_raw_value(_, _, _), do: nil

  def get_raw_value(entity_id, path) when is_binary(path) do
    get_raw_value(entity_id, String.split(path, ":"))
  end

  def get_raw_value(entity_id, []), do: details(entity_id)

  # TODO: make more efficient using a Repo.exists? query on entity_id/detail
  def get_raw_value(entity_id, [detail]) do
    0 !=
      entity_id
      |> get()
      |> Map.get(detail, %{})
      |> map_size
  end

  def get_raw_value(entity_id, [detail, component | rest]) do
    info =
      entity_id
      |> get()
      |> Map.get(detail, %{})

    case {component, rest} do
      {component, []} when component in ~w[short related_to related_by] ->
        Map.get(info, component, nil)

      {component, []} when component in ~w[nouns adjectives] ->
        Map.get(info, component, [])

      {component, []} when component in ~w[exits enters jumps climbs] ->
        info
        |> Map.get(component, %{})
        |> Map.keys()

      {component, [word]} when component in ~w[nouns adjectives] ->
        word in Map.get(info, component, [])

      {component, [exit_path]} when component in ~w[exits enters jumps climbs] ->
        get_exit_info(Map.get(info, component, %{}), exit_path)

      {component, path} ->
        path
        |> Enum.reduce(Map.get(info, component, nil), fn
          _, nil -> nil
          name, map -> Map.get(map, name)
        end)

      _ ->
        nil
    end
  end

  defp get_exit_info(exit_info, [dir]) do
    case Map.get(exit_info, dir) do
      %{target: t} when not is_nil(t) -> true
      _ -> false
    end
  end

  defp get_exit_info(exit_info, [dir, field]) do
    with %{} = info <- Map.get(exit_info, dir) do
      Map.get(info, field)
    else
      _ -> nil
    end
  end

  @doc """
  Valid fields:
  - target
  - coord
  - relationship (preposition)
  - form (for jump, climb, enter)
  """
  defp get_exit_info(exit_info, [dir, field]) do
    exit_info
    |> Map.get(dir, %{})
    |> Map.get(field, nil)
  end

  def hibernate(_entity_id), do: :ok
  def unhibernate(_entity_id), do: :ok

  def where({entity_id, "default"}), do: Militerm.Services.Location.where({:thing, entity_id})

  def where({entity_id, detail}) do
    with %{"related_by" => prep, "related_to" => parent_detail} <- get(entity_id, detail) do
      if is_nil(prep) or is_nil(parent_detail), do: nil, else: {prep, {entity_id, parent_detail}}
    else
      _ -> nil
    end
  end

  @doc """
  Lists all of the detail coordinates for a particular entity.

  ## Examples

    iex> Details.set("room1", "default", %{})
    ...> Details.set("room1", "northwall", %{related_to: "default", related_by: "in"})
    ...> Details.set("room1", "southwall", %{related_to: "default", related_by: "in"})
    ...> Details.set("room1", "floor", %{related_to: "default", related_by: "in"})
    ...> Details.details("room1") |> Enum.sort
    ["default", "floor", "northwall", "southwall"]
  """
  def details(entity_id, detail \\ "default") do
    entity_id
    |> get(%{})
    |> Map.keys()
  end

  def get(entity_id) do
    Militerm.ECS.Component.get(__MODULE__, entity_id, %{})
  end

  def get(entity_id, default) when not is_binary(default) do
    Militerm.ECS.Component.get(__MODULE__, entity_id, default)
  end

  def get(entity_id, detail) when is_binary(detail) do
    entity_id
    |> get(%{})
    |> Map.get(detail, %{})
  end

  def get(entity_id, detail, default) do
    entity_id
    |> get(%{})
    |> Map.get(detail, default)
  end

  @doc """
  ## Examples

    iex> Details.set("room2", "default", %{short: "room"})
    ...> Details.get("room2", "default")
    %{"short" => "room"}

    iex> Details.set("room3", %{"default" => %{short: "room"}, "floor" => %{short: "the floor"}})
    ...> Details.get("room3", "floor")
    %{"short" => "the floor"}
    ...> Details.details("room3") |> Enum.sort
    ["default", "floor"]
  """
  def set(entity_id, detail, values) do
    Militerm.ECS.Component.update(__MODULE__, entity_id, fn
      nil -> %{detail => atoms_to_strings(values)}
      map -> Map.put(map, detail, atoms_to_strings(values))
    end)
  end

  def set(entity_id, details) when is_map(details) do
    Militerm.ECS.Component.set(__MODULE__, entity_id, details)
  end

  def remove(entity_id, detail) do
    Militerm.ECS.Component.update(__MODULE__, entity_id, fn
      nil ->
        nil

      map ->
        new_map = Map.drop(map, detail)
        if map_size(new_map) == 0, do: nil, else: new_map
    end)
  end

  def remove(entity_id) do
    Militerm.ECS.Component.remove(__MODULE__, entity_id)
  end

  def atoms_to_strings(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {atoms_to_strings(k), atoms_to_strings(v)} end)
    |> Enum.into(%{})
  end

  def atoms_to_strings(list) when is_list(list) do
    Enum.map(list, fn v -> atoms_to_strings(v) end)
  end

  def atoms_to_strings(atom) when is_atom(atom), do: to_string(atom)

  def atoms_to_strings(otherwise), do: otherwise
end

defmodule Militerm.Components.Location do
  use Militerm.ECS.EctoComponent,
    default: %{},
    schema: Militerm.Data.Location

  import Ecto.Query

  def write_data(map, data) do
    Map.merge(map, data)
  end

  def read_data(nil), do: %{}
  def read_data(map), do: Map.drop(map, ~w[inserted_at updated_at __struct__ __meta__ id]a)

  def get_value(entity_id, path) do
    get_raw_value(entity_id, path)
  end

  def get_raw_value(entity_id, path) do
    case path do
      ["environment"] -> get_environment(entity_id)
      ["location"] -> get_location(entity_id)
      ["position"] -> position(entity_id)
      ["proximity"] -> get_proximity(entity_id)
      _ -> nil
    end
  end

  defp get_environment(entity_id) do
    case get(entity_id) do
      %{target_id: target_id} -> {:thing, target_id}
      _ -> nil
    end
  end

  defp get_location(entity_id) do
    case get(entity_id) do
      %{target_id: target_id, t: t} when not is_nil(t) ->
        {:thing, target_id, t}

      %{target_id: target_id, point: p} when not is_nil(p) ->
        {:thing, target_id, List.to_tuple(p)}

      %{target_id: target_id, detail: detail} when not is_nil(detail) ->
        {:thing, target_id, detail}

      _ ->
        nil
    end
  end

  defp get_proximity(entity_id) do
    case get(entity_id) do
      %{relationship: rel} -> rel
      _ -> nil
    end
  end

  def set_value(entity_id, path, value) do
    # check validations
    set_raw_value(entity_id, path, value)
  end

  def set_raw_value(entity_id, path, value) do
    case path do
      ["position"] ->
        Militerm.ECS.Component.update(__MODULE__, entity_id, fn
          nil -> %{position: value}
          map -> Map.put(map, :position, value)
        end)

      _ ->
        value
    end
  end

  def remove_value(entity_id, path) do
    case path do
      ["position"] ->
        Militerm.ECS.Component.update(__MODULE__, entity_id, fn
          nil -> nil
          map -> Map.delete(map, :position)
        end)

      _ ->
        :ok
    end
  end

  def position(entity_id, default \\ nil) do
    case get(entity_id) do
      %{position: pos} -> pos
      _ -> default
    end
  end

  def hibernate(entity_id) do
    case get(entity_id) do
      %{hibernated: true} ->
        :ok

      _ ->
        Militerm.ECS.Component.update(__MODULE__, entity_id, fn
          nil -> %{hibernated: true}
          map -> Map.put(map, :hibernated, true)
        end)
    end
  end

  def unhibernate(entity_id) do
    case get(entity_id) do
      %{hibernated: true} ->
        Militerm.ECS.Component.update(__MODULE__, entity_id, fn
          nil -> %{hibernated: false}
          map -> Map.put(map, :hibernated, false)
        end)

      _ ->
        :ok
    end
  end

  @doc """
  Lists entities that are located in the given target entity.

  ## Examples
    iex> LocationService.place({:thing, "123"}, {"near", {:thing, "234", "default"}})
    ...> LocationService.place({:thing, "456"}, {"near", {:thing, "234", "nugget"}})
    ...> LocationService.place({:thing, "789"}, {"near", {:thing, "235", "default"}})
    ...> Enum.sort(Location.find_in("234"))
    ["123", "456"]
  """
  def find_in(target_id, opts \\ []) do
    Militerm.Data.Location
    |> where([u], u.target_id == ^target_id)
    |> excluding_proxes(opts)
    |> including_proxes(opts)
    |> select([u], u.entity_id)
    |> Militerm.Config.repo().all()
  end

  @doc """
  Lists entities that are at the given target/location within an optional delta.

  ## Examples

    iex> LocationService.place({:thing, "123"}, {"near", {:thing, "234", "default"}})
    ...> LocationService.place({:thing, "456"}, {"near", {:thing, "234", "nugget"}})
    ...> LocationService.place({:thing, "789"}, {"near", {:thing, "235", "default"}})
    ...> Location.find_at("234", "nugget")
    ["456"]
  """
  def find_at(target_id) do
    Militerm.Data.Location
    |> Militerm.Config.repo().all()

    Militerm.Data.Location
    |> where(
      [u],
      u.target_id == ^target_id and not u.hibernated
    )
    |> select([u], u.entity_id)
    |> Militerm.Config.repo().all()
  end

  def find_at(target_id, coord, opts \\ [delta: 0])

  # def find_at(target_id, t) when is_number(t), do: find_at(target_id, t, delta: 0)

  def find_at(target_id, detail, opts) when is_binary(detail) do
    Militerm.Data.Location
    |> where(
      [u],
      u.target_id == ^target_id and u.detail == ^detail and not u.hibernated
    )
    |> excluding_proxes(opts)
    |> including_proxes(opts)
    |> select([u], u.entity_id)
    |> Militerm.Config.repo().all()
  end

  # def find_at(target_id, {_, _, _} = p), do: find_at(target_id, p, delta: 0)

  def find_at(target_id, t, opts) when is_number(t) do
    delta = Keyword.get(opts, :delta, 0)

    Militerm.Data.Location
    |> where([u], u.target_id == ^target_id and not u.hibernated)
    |> excluding_proxes(opts)
    |> including_proxes(opts)
    |> select([u], {u.entity_id, u.t})
    |> Militerm.Config.repo().all()
    |> Enum.filter(fn {_, tt} -> abs(t - tt) <= delta end)
    |> Enum.map(fn {entity_id, _} -> entity_id end)
  end

  def find_at(target_id, {_, _, _} = c, opts) do
    delta = Keyword.get(opts, :delta, 0)
    excluded_proxes = Keyword.get(opts, :excluding, [])

    Militerm.Data.Location
    |> where([u], u.target_id == ^target_id and not u.hibernated)
    |> excluding_proxes(opts)
    |> including_proxes(opts)
    |> select([u], {u.entity_id, u.point})
    |> Militerm.Config.repo().all()
    |> Enum.filter(fn {_, p} -> distance(p, c) <= delta end)
    |> Enum.map(fn {entity_id, _} -> entity_id end)
  end

  defp excluding_proxes(query, opts) do
    case Keyword.get(opts, :excluding, []) do
      [_ | _] = proxes ->
        where(query, [u], u.relationship not in ^proxes)

      _ ->
        query
    end
  end

  defp including_proxes(query, opts) do
    case Keyword.get(opts, :including, []) do
      [_ | _] = proxes ->
        where(query, [u], u.relationship in ^proxes)

      _ ->
        query
    end
  end

  @spec distance(list, tuple) :: number
  defp distance(p, c) do
    deltax = Enum.at(p, 0) - elem(c, 0)
    deltay = Enum.at(p, 1) - elem(c, 1)
    deltaz = Enum.at(p, 2) - elem(c, 2)
    :math.sqrt(deltax * deltax + deltay * deltay + deltaz * deltaz)
  end
end

defmodule Militerm.Services.Location do
  @doc """
  Place the entity_id at the given coordinate of the target entity.

  ## Example
    iex> Location.place({:thing, "123"}, {"near", {:thing, "234", "default"}})
    ...> LocationComponent.get("123")
    %{target_id: "234", relationship: "near", detail: "default"}
  """
  def place({:thing, entity_id}, {prep, {:thing, target_id, t}}) when is_number(t) do
    new_data = %{
      target_id: target_id,
      t: t,
      relationship: prep
    }

    # ensure the target location exists
    Militerm.Components.Location.update(entity_id, fn
      nil -> new_data
      old_data -> Map.merge(old_data, new_data)
    end)
  end

  def place({:thing, entity_id}, {prep, {:thing, target_id, detail}}) when is_binary(detail) do
    new_data = %{
      target_id: target_id,
      relationship: prep,
      detail: detail
    }

    Militerm.Components.Location.update(entity_id, fn
      nil -> new_data
      old_data -> Map.merge(old_data, new_data)
    end)
  end

  def place({:thing, entity_id}, {prep, {:thing, target_id, {x, y, z}}}) do
    new_data = %{
      target_id: target_id,
      relationship: prep,
      point: [x, y, z]
    }

    Militerm.Components.Location.update(entity_id, fn
      nil -> new_data
      old_data -> Map.merge(old_data, new_data)
    end)
  end

  @doc """
  Returns the location of the entity as a two-member tuple:
    {prep, {:thing, target_entity_id, t}}
    {prep, {:thing, target_entity_id, detail}}
    {prep, {:thing, target_entity_id, {x, y, z}}}

  ## Example
    iex> Location.place({:thing, "123"}, {"near", {:thing, "234", "default"}})
    ...> Location.where({:thing, "123"})
    {"near", {:thing, "234", "default"}}
  """
  def where({:thing, entity_id, "default"}), do: where({:thing, entity_id})

  def where({:thing, entity_id, detail}) when is_binary(detail) do
    # query the relationship from the entity
    case Militerm.Components.Details.where({entity_id, detail}) do
      {prep, {target_id, target_coord}} ->
        {prep, {:thing, target_id, target_coord}}

      _ ->
        nil
    end
  end

  def where({:thing, entity_id}) do
    case Militerm.Components.Location.get(entity_id) do
      %{target_id: target_id, t: t, relationship: prep} when not is_nil(t) ->
        {prep, {:thing, target_id, t}}

      %{target_id: target_id, point: p, relationship: prep} when not is_nil(p) ->
        {prep, {:thing, target_id, List.to_tuple(p)}}

      %{target_id: target_id, relationship: prep, detail: detail} ->
        {prep, {:thing, target_id, detail}}

      _ ->
        nil
    end
  end

  def environment({:thing, entity_id}) do
    case Militerm.Components.Location.get(entity_id) do
      %{target_id: target_id} -> {:thing, target_id}
      _ -> nil
    end
  end

  @doc """
  Returns all the entities in thing, but not details of thing.
  """
  def all_entities(thing) do
    thing_id =
      case thing do
        {:thing, id} -> id
        {:thing, id, _} -> id
      end

    thing_id
    |> Militerm.Components.Location.find_in()
    |> Enum.map(fn id -> {:thing, id} end)
  end

  def find_in(thing, steps \\ 1, acc \\ [])

  def find_in(nil, _, acc), do: acc

  def find_in(thing, steps, acc) when is_tuple(thing) do
    find_in([thing], steps, acc)
  end

  def find_in([], _, acc), do: acc

  def find_in(things, 0, acc) when is_list(things), do: things ++ acc

  def find_in(things, steps, acc) when is_list(things) do
    next_steps = if steps == :infinite, do: :infinite, else: steps - 1

    new_things =
      things
      |> Enum.flat_map(fn
        {:thing, thing_id, coord} ->
          other_things =
            thing_id
            |> Militerm.Components.Location.find_at(coord)
            |> Enum.map(fn entity_id -> {:thing, entity_id} end)

          other_details =
            thing_id
            |> Militerm.Components.Details.get()
            |> Enum.filter(fn {detail, info} ->
              Map.get(info, "related_to") == coord
            end)
            |> Enum.map(fn {detail, _} -> {:thing, thing_id, detail} end)

          other_things ++ (other_details -- things)

        {:thing, thing_id} ->
          other_things =
            thing_id
            |> Militerm.Components.Location.find_at("default")
            |> Enum.map(fn entity_id -> {:thing, entity_id} end)

          other_details =
            thing_id
            |> Militerm.Components.Details.get()
            |> Enum.filter(fn {detail, info} ->
              Map.get(info, "related_to") == "default"
            end)
            |> Enum.map(fn {detail, _} -> {:thing, thing_id, detail} end)

          other_things ++ (other_details -- things)
      end)

    find_in(new_things, next_steps, things ++ acc)
  end

  def find_near({:thing, _} = target), do: find_near(target, 3)
  def find_near({:thing, _, _} = target), do: find_near(target, 2)
  def find_near(nil), do: []

  def find_near({:thing, entity_id}, steps) when is_binary(entity_id) do
    case Militerm.Components.Location.get(entity_id) do
      %{hibernated: true} -> []
      %{target_id: target_id, detail: detail} -> find_near({:thing, target_id, detail}, steps - 1)
      _ -> []
    end
  end

  def find_near({:thing, target_id, _} = target, steps) do
    case Militerm.Components.Location.get(target_id) do
      %{hibernated: true} ->
        []

      _ ->
        find_near([target], Militerm.Components.Details.details(target_id), steps)
    end
  end

  def find_near(list, _, 0) when is_list(list), do: list

  def find_near(list, details, steps) when is_list(list) do
    scene_details =
      list
      |> Enum.flat_map(&do_find_near(&1, details))

    items =
      list
      |> Enum.flat_map(&do_find_related(&1))

    (scene_details ++ items)
    |> Enum.uniq()
    |> find_near(details, steps - 1)
  end

  def do_find_related({:thing, target_id}), do: do_find_related({:thing, target_id, "default"})

  def do_find_related({:thing, target_id, coord}) do
    target_id
    |> Militerm.Components.Location.find_at(coord)
    |> Enum.map(fn
      entity_id when is_binary(entity_id) -> {:thing, entity_id}
    end)
  end

  def do_find_near({:thing, target_id}, details) do
    do_find_near({:thing, target_id, "default"}, details)
  end

  def do_find_near({:thing, target_id, detail}, details) when is_binary(detail) do
    # one step up and down relationship graph
    children =
      details
      |> Enum.flat_map(fn d ->
        case Militerm.Components.Details.where({target_id, d}) do
          {prep, {_, ^detail}} -> [{:thing, target_id, d}]
          _ -> []
        end
      end)

    case Militerm.Components.Details.where({target_id, detail}) do
      {_, {_, d}} -> [{:thing, target_id, d} | children]
      _ -> children
    end
  end

  ###
  ### Relationship graph
  ###

  @doc """
  Calculates the shortest path between v1 and v2.

  This is useful when trying to figure out how two things in a scene are related.
  If two things are in different scenes, then it's how each item relates to
  "default" in their scenes, and how the scenes are then related to each other.
  Scenes can also relate through exits/entrances, which are tied to details or
  other coordinates.

  When descfribing a scene, describe one step up/down from the POV location, and
  the "default" detail. If the detail isn't directly related to the "default"
  detail, then state that it's "in" the "default" space.

  returns {vertex_list, {weight, edge_count}} | nil

  `nil` is returned if there isn't a simple path between the two objects.

  statue->ON->pedestal->NEAR->northwall->IN->room
              painting->ON-/              |
     bowl->ON->table->NEAR->southwall->IN-/
    spoon->ON-/                           |
  chair->NEAR-/                           |
                                floor->IN-/


  ## Examples

    iex> Details.set("boom", "default", %{})
    ...> Details.set("boom", "northwall", %{related_to: "default", related_by: "in"})
    ...> Details.set("boom", "southwall", %{related_to: "default", related_by: "in"})
    ...> Details.set("boom", "floor", %{related_to: "default", related_by: "in"})
    ...> Details.set("boom", "pedestal", %{related_to: "northwall", related_by: "near"})
    ...> Details.set("boom", "painting", %{related_to: "northwall", related_by: "on"})
    ...> Details.set("boom", "statue", %{related_to: "pedestal", related_by: "on"})
    ...> Details.set("boom", "table", %{related_to: "southwall", related_by: "near"})
    ...> Details.set("boom", "bowl", %{related_to: "table", related_by: "on"})
    ...> Details.set("boom", "spoon", %{related_to: "table", related_by: "on"})
    ...> Details.set("boom", "chair", %{related_to: "table", related_by: "near"})
    ...> Location.shortest_path({:thing, "boom", "chair"}, {:thing, "boom", "pedestal"})
    [{:thing, "boom", "chair"}, {:thing, "boom", "table"}, {:thing, "boom", "southwall"}, {:thing, "boom", "default"}, {:thing, "boom", "northwall"}, {:thing, "boom", "pedestal"}]
    ...> Location.shortest_path({:thing, "boom", "statue"}, {:thing, "boom", "painting"})
    [{:thing, "boom", "statue"}, {:thing, "boom", "pedestal"}, {:thing, "boom", "northwall"}, {:thing, "boom", "painting"}]
    ...> Location.shortest_path({:thing, "boom", "chair"}, {:thing, "boom", "table"})
    [{:thing, "boom", "chair"}, {:thing, "boom", "table"}]

    iex> Details.set("koom", "default", %{})
    ...> Details.set("koom", "northwall", %{related_to: "default", related_by: "in"})
    ...> Details.set("koom", "southwall", %{related_to: "default", related_by: "in"})
    ...> Details.set("koom", "floor", %{related_to: "default", related_by: "in"})
    ...> Location.place({:thing, "pedestal"}, {"near", {:thing, "koom", "northwall"}})
    ...> Location.place({:thing, "statue"}, {"on", {:thing, "pedestal", "default"}})
    ...> Location.place({:thing, "painting"}, {"on", {:thing, "koom", "northwall"}})
    ...> Location.place({:thing, "table"}, {"near", {:thing, "koom", "southwall"}})
    ...> Location.place({:thing, "bowl"}, {"on", {:thing, "table", "default"}})
    ...> Location.place({:thing, "spoon"}, {"on", {:thing, "table", "default"}})
    ...> Location.place({:thing, "chair"}, {"near", {:thing, "table", "default"}})
    ...> Location.shortest_path({:thing, "chair", "default"}, {:thing, "pedestal", "default"})
    [{:thing, "chair", "default"}, {:thing, "table", "default"}, {:thing, "koom", "southwall"}, {:thing, "koom", "default"}, {:thing, "koom", "northwall"}, {:thing, "pedestal", "default"}]
    ...> Location.shortest_path({:thing, "chair", "default"}, {:thing, "table", "default"})
    [{:thing, "chair", "default"}, {:thing, "table", "default"}]
    ...> Location.shortest_path({:thing, "table", "default"}, {:thing, "chair", "default"})
    [{:thing, "table", "default"}, {:thing, "chair", "default"}]
  """
  def shortest_path(a, b) do
    shortest_path(a, b, [], [])
  end

  def shortest_path(a, b, a_path, b_path) do
    a_parent = if a, do: where(a), else: nil
    b_parent = if b, do: where(b), else: nil

    case {a_parent, b_parent} do
      {{_, n}, {_, n}} ->
        Enum.reverse(a_path) ++ [a, n, b] ++ b_path

      {{_, a_p}, {_, b_p}} ->
        cond do
          a_p in b_path ->
            meld_paths(a_parent, a_path, b_path)

          b_p in a_path ->
            meld_paths(b_parent, b_path, a_path)

          :else ->
            shortest_path(a_p, b_p, [a | a_path], [b | b_path])
        end

      {nil, {_, b_p}} ->
        if b_p in a_path do
          # we're done
          meld_paths(b_parent, [b_p, b | b_path], a_path)
        else
          shortest_path(nil, b_p, if(a, do: [a | a_path], else: a_path), [b | b_path])
        end

      {{_, a_p}, nil} ->
        if a_p in b_path do
          meld_paths(a_parent, [a_p, a | a_path], b_path)
        else
          shortest_path(a_p, nil, [a | a_path], if(b, do: [b | b_path], else: b_path))
        end

      {nil, nil} ->
        # either we're out, or we're at the root
        a_path = if(a, do: [a | a_path], else: a_path)
        b_path = if(b, do: [b | b_path], else: b_path)
        {a_path, b_path} = collapse_similar(a_path, b_path)
        a_idx = Enum.find_index(a_path, fn n -> n in b_path end)

        if a_idx do
          # there's overlap!
          p = Enum.at(a_path, a_idx)
          b_idx = Enum.find_index(b_path, fn n -> n == p end)
          a_path = Enum.slice(a_path, a_idx + 1, Enum.count(a_path) - a_idx)
          b_path = Enum.slice(b_path, b_idx + 1, Enum.count(b_path) - b_idx)
          {a_path, b_path} = collapse_similar(a_path, b_path)
          Enum.reverse(a_path) ++ [p] ++ b_path
        else
          nil
        end
    end
  end

  def meld_paths({_, pivot}, a_path, b_path) do
    a_path =
      if pivot in a_path do
        idx = Enum.find_index(a_path, fn n -> n == pivot end)
        Enum.slice(a_path, idx + 1, Enum.count(a_path) - idx)
      else
        a_path
      end

    b_path =
      if pivot in b_path do
        idx = Enum.find_index(b_path, fn n -> n == pivot end)
        Enum.slice(b_path, idx + 1, Enum.count(b_path) - idx)
      else
        b_path
      end

    {a_path, b_path} = collapse_similar(a_path, b_path)
    Enum.reverse(a_path) ++ [pivot] ++ b_path
  end

  def collapse_similar([n | [m | _] = a_path], [n | [m | _] = b_path]),
    do: collapse_similar(a_path, b_path)

  def collapse_similar([n | _] = a_path, [n | _] = b_path), do: {a_path, b_path}

  def collapse_similar(a_path, b_path), do: {a_path, b_path}
end

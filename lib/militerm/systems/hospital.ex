defmodule Militerm.Systems.Hospital do
  use Militerm.ECS.System

  @moduledoc """
  A hospital manages the NPCs that can appear in places.

  Each domain and area can have hospital configurations.

  Hospital data is structured:

  - Zones
    - name
    - npc-chance
    - group-chance
    - npcs
    - groups
    - sub-zones (other zones to consider if no npc/group created from this)
  - NPCs
    - name
    - archetype
    - data (for each possible component)
    - init code (script that gets run when the hospital creates an NPC)
    - is_unique (if only one of these ever exists)
    - cooldown (seconds before respawning if unique)
    - max_population (if not unique, the maximum that can be around at once)
  - Groups
    - name
    - is_unique (useful for boss groups)
    - cooldown
    - max_population
    - NPCs
      - name
      - number (dice roll)

  Once we have a way to wear and wield things:
    The hospital works with the armory to create clothes and weapons for NPCs.
    The hospital works with the warehouse to create other items.
  """

  defscript hospital_populate(), for: %{"this" => this} = objects do
    # figures out the hospital/zone and populates if necessary
    # doesn't do anything if there are already NPCs and players in the space
    # This function will usually be called *before* the player enters the room
    #
    # adds 'flag:transient' if the npc is transient
    stuff_here = Militerm.Services.Location.all_entities(this)

    if !hospital_things?(stuff_here) && !players?(stuff_here) do
      {domain, area, location} = domain_area_location(this, objects)
      zone = Militerm.Systems.Entity.property(this, ~w[trait hospital zone], objects)

      if domain && area && (location || zone) do
        json =
          case Militerm.Cache.Hospital.get({domain, area}) do
            %{} = data -> data
            _ -> Militerm.Cache.Hospital.get(domain)
          end

        if json do
          if zone do
            populate_by_zone(this, json, zone, %{
              "trait" => %{
                "hospital" => %{
                  "domain" => domain,
                  "area" => area,
                  "zone" => zone
                }
              }
            })
          else
            populate_by_location(this, json, location, %{
              "trait" => %{
                "hospital" => %{
                  "domain" => domain,
                  "area" => area,
                  "location" => location
                }
              }
            })
          end
        end
      end
    end
  end

  defscript hospital_depopulate(), for: %{"this" => this} = objects do
    # removes any transient entities from the scene
    # might someday save entities so we can reuse them reather than destroy/recreate constantly
    stuff_here = Militerm.Services.Location.all_entities(this)

    if hospital_things?(stuff_here) && !players?(stuff_here) do
      tbd =
        stuff_here
        |> hospital_things
        |> Enum.filter(fn entity ->
          Militerm.Systems.Entity.property(entity, ~w[flag is-transient], objects)
        end)

      for entity <- tbd do
        Militerm.Systems.Events.trigger(entity, "object:destroy", "object", %{"this" => entity})
      end
    end
  end

  defscript hospital_describe_business(), for: %{"this" => this} = _objects do
    # takes the time of day, etc., into account and produces a string
    # representing how busy the scene is, in general. The actual strings
    # can come from the detail component.
  end

  def hospital_things?(things) do
    Enum.any?(things, fn entity ->
      Militerm.Systems.Entity.property(entity, ~w[flag made-by-hospital], %{"this" => entity})
    end)
  end

  def hospital_things(things) do
    things
    |> Enum.filter(fn entity ->
      Militerm.Systems.Entity.property(entity, ~w[flag made-by-hospital], %{"this" => entity})
    end)
  end

  def players?(things) do
    Enum.any?(things, fn entity ->
      Militerm.Systems.Entity.is?(entity, "player", %{"this" => entity})
    end)
  end

  def players(things) do
    Enum.filter?(things, fn entity ->
      Militerm.Systems.Entity.is?(entity, "player", %{"this" => entity})
    end)
  end

  def domain_area_location(this, objects) do
    entity_id =
      case this do
        {:thing, id} -> id
        {:thing, id, _} -> id
      end

    {implicit_domain, implicit_area, implicit_location} =
      case String.split(entity_id, ":", trim: true, parts: 4) do
        ["scene", d, a, l] -> {d, a, l}
        ["scene", d, a | _] -> {d, a, nil}
        ["scene", d | _] -> {d, nil, nil}
        _ -> {nil, nil, nil}
      end

    explicit_domain = Militerm.Systems.Entity.property(this, ~w[trait hospital domain], objects)

    explicit_area = Militerm.Systems.Entity.property(this, ~w[trait hospital area], objects)

    explicit_location =
      Militerm.Systems.Entity.property(this, ~w[trait hospital location], objects)

    {explicit_domain || implicit_domain, explicit_area || implicit_area,
     explicit_location || implicit_location}
  end

  def populate_by_zone(this, json, zone, data) do
    info =
      json
      |> Map.get("zones", %{})
      |> Map.get(zone)

    populate(this, info, json, data)
  end

  def populate_by_location(this, json, location, data) do
    info =
      json
      |> Map.get("locations", %{})
      |> Map.get(location)

    populate(this, info, json, data)
  end

  def populate(_, nil, _, _), do: false

  def populate(this, info, json, data) do
    maybe_populate_with_npc(this, info, json, data) ||
      maybe_populate_with_group(this, info, json, data)
  end

  def maybe_populate_with_npc(this, %{"npc-chance" => chance, "npcs" => npcs}, json, data) do
    if chance >= :rand.uniform(100) do
      create_any_npc(this, npcs, json, data)
    end
  end

  def maybe_populate_with_npc(this, %{"npcs" => npcs}, json, data) do
    create_any_npc(this, npcs, json, data)
  end

  def maybe_populate_with_npc(_, _, _, _), do: false

  def maybe_populate_with_group(this, %{"group-chance" => chance, "groups" => groups}, json, data) do
    if chance >= :rand.uniform(100) do
      create_any_group(this, groups, json, data)
    end
  end

  def maybe_populate_with_group(this, %{"groups" => groups}, json, data) do
    create_any_group(this, groups, json, data)
  end

  def maybe_populate_with_group(_, _, _, _), do: false

  def create_any_npc(this, npcs, json, data) do
    selected = select_item(npcs)

    if selected do
      create_npc(this, selected, json, data, Map.get(npcs, selected))
    end
  end

  def create_npc(this, npc, json, data, placement_data) do
    info =
      json
      |> Map.get("npcs", %{})
      |> Map.get(npc)

    if info do
      # create npc
      archetype = Map.get(info, "archetype", "std:npc")

      data =
        info
        |> Map.get("data", %{})
        |> put_in([Access.key("flag", %{}), Access.key("made-by-hospital")], true)

      loc = place(this, placement_data)

      {:thing, entity_id} = entity = Militerm.Systems.Entity.create(archetype, loc, data)

      if Map.get(info, "is_transient") do
        Militerm.Components.Flags.set(entity_id, ["hospital:transient"])
      end

      entity
    end
  end

  defp place(thing, placement_data) do
    entity_id =
      case thing do
        {:thing, id} -> id
        {:thing, id, _} -> id
      end

    {prox, detail} =
      case Map.get(placement_data, "placement") do
        %{} = map ->
          [{prox, detail} | _] = Map.to_list(map)
          {prox, detail}

        list when is_list(list) ->
          [{prox, detail} | _] =
            list
            |> Enum.at(:rand.uniform(Enum.count(list)) - 1)
            |> Map.to_list()

          {prox, detail}

        detail when is_binary(detail) ->
          # get default proximity for the detail
          prox =
            Militerm.Systems.Entity.property(
              {:thing, entity_id, detail},
              ["detail", detail, ":default-proximity"],
              %{"this" => {:thing, entity_id, detail}}
            )

          {prox || "in", detail}

        _ ->
          {"in", "default"}
      end

    case thing do
      {:thing, id} -> {prox, {:thing, id, detail}}
      {:thing, id, _} -> {prox, {:thing, id, detail}}
    end
  end

  defp total_chance(set) do
    set
    |> Enum.map(fn
      {_, n} when is_number(n) -> n
      {_, %{"chance" => n}} -> n
      _ -> 1
    end)
    |> Enum.sum()
  end

  defp select_item(set) do
    total = total_chance(set)

    {selected, _} =
      Enum.reduce_while(set, {nil, :rand.uniform(total)}, fn {item, info}, {_, acc} ->
        chance =
          case info do
            %{"chance" => n} -> n
            n when is_number(n) -> n
            _ -> 1
          end

        # 1 <= acc <= total
        # 0 <= chance <= total
        if acc <= chance do
          {:halt, {item, 0}}
        else
          {:cont, {item, acc - chance}}
        end
      end)

    selected
  end

  def create_any_group(this, groups, json, data) do
    selected = select_item(groups)

    if selected do
      create_group(this, selected, json, data, Map.get(groups, selected))
    end
  end

  def create_group(this, group, json, data, placement_data) do
    info =
      json
      |> Map.get("groups", %{})
      |> Map.get(group)

    if info do
      nil
    end
  end
end

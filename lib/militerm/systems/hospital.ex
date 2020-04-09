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

  defscript populate(), for: %{"this" => {:thing, entity_id} = this} = _objects do
    # figures out the hospital/zone and populates if necessary
    # doesn't do anything if there are already NPCs and players in the space
    # This function will usually be called *before* the player enters the room
    #
    # adds 'flag:transient' if the npc is transient

    domain = Militerm.Systems.Entity.property(entity_id, ~w[trait hospital domain])
    area = Militerm.Systems.Entity.property(entity_id, ~w[trait hospital area])
    location = Militerm.Systems.Entity.property(entity_id, ~w[trait hospital location])
    zone = Militerm.Systems.Entity.property(entity_id, ~w[trait hospital zone])

    if domain and area and (location or zone) do
      hospital_file =
        Path.join([Militerm.Config.game_dir(), "domains", domain, "areas", area, "hospital.yaml"])

      if File.exists?(hospital_file) do
        json = YamlElixir.read_from_file!(hospital_file)

        if zone do
          populate_by_zone(this, json, zone, %{
            "trait" => %{
              "hospital:domain" => domain,
              "hospital:area" => area,
              "hospital:zone" => zone
            }
          })
        else
          populate_by_location(this, json, location, %{
            "trait" => %{
              "hospital:domain" => domain,
              "hospital:area" => area,
              "hospital:location" => location
            }
          })
        end
      end
    end
  end

  defscript depopulate(), for: %{"this" => this} = _objects do
    # removes any transient entities from the scene
    # might someday save entities so we can reuse them reather than destroy/recreate constantly
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
    total =
      npcs
      |> Enum.map(fn {_, n} -> n end)
      |> Enum.sum()

    {selected, _} =
      Enum.reduce_while(npcs, {nil, :rand.uniform(total)}, fn {npc, chance}, {_, acc} ->
        if acc <= chance do
          {:halt, {npc, 0}}
        else
          {:cont, {npc, acc - chance}}
        end
      end)

    if selected do
      create_npc(this, selected, json, data)
    end
  end

  def create_npc(this, npc, json, data) do
    info =
      json
      |> Map.get("npcs", %{})
      |> Map.get(npc)

    if info do
      nil
    end
  end

  def create_any_group(this, groups, json, data) do
    total =
      groups
      |> Enum.map(fn {_, n} -> n end)
      |> Enum.sum()

    {selected, _} =
      Enum.reduce_while(groups, {nil, :rand.uniform(total)}, fn {group, chance}, {_, acc} ->
        if acc <= chance do
          {:halt, {group, 0}}
        else
          {:cont, {group, acc - chance}}
        end
      end)

    if selected do
      create_group(this, selected, json, data)
    end
  end

  def create_group(this, group, json, data) do
    info =
      json
      |> Map.get("groups", %{})
      |> Map.get(group)

    if info do
      nil
    end
  end
end

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

  defscript populate(), for: %{"this" => this} = _objects do
    # figures out the hospital/zone and populates if necessary
    # doesn't do anything if there are already NPCs and players in the space
    # This function will usually be called *before* the player enters the room
  end
end

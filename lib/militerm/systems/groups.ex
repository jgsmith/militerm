defmodule Militerm.Systems.Groups do
  @moduledoc """
  The Groups system provides a way to manage privilege escalation and
  use.

  Escalated group memberships are ephemeral and disappear when the
  character leaves the game.
  """

  use Militerm.ECS.System

  alias Militerm.Components.EphemeralGroup
  alias Militerm.English
  alias Militerm.Systems.Entity

  defcommand su(bits), for: %{"this" => {:thing, entity_id} = this} = args do
    # the user has to have been granted the group membership in order to
    # add it to their session
    case String.split(bits, ~r{\s+}, trim: true) do
      [] ->
        # list out the current groups turned on
        list =
          entity_id
          |> EphemeralGroup.get_groups()

        Entity.receive_message(
          this,
          "cmd",
          "You have #{English.consolidate(Enum.count(list), "group")} active: #{
            English.item_list(list)
          }"
        )

      groups ->
        candidates = groups -- EphemeralGroup.get_groups(entity_id)

        list =
          candidates
          |> Enum.filter(&EphemeralGroup.set_value(entity_id, [&1], true))

        Entity.receive_message(
          this,
          "cmd",
          "Activated #{English.consolidate(Enum.count(list), "group")}: #{English.item_list(list)}"
        )
    end
  end

  defcommand unsu(bits), for: %{"this" => {:thing, entity_id} = this} = args do
    list =
      case String.split(bits, ~r{\s+}, trim: true) do
        [] -> EphemeralGroup.get_groups(entity_id) -- ["players"]
        groups -> groups -- ["players"]
      end

    for group <- list, do: EphemeralGroup.set_value(entity_id, [group], false)

    Entity.receive_message(
      this,
      "cmd",
      "Deactivated #{English.consolidate(Enum.count(list), "group")}: #{English.item_list(list)}"
    )
  end
end

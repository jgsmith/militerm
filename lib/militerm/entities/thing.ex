defmodule Militerm.Entities.Thing do
  @moduledoc """
  The basic entity that is based on an archetype. It merges data from the archetype
  with any data given to it and then creates the entity.

  For most games, this will be sufficient when combined with the archetype and mixin
  scripts.

  N.B.: The core game engine does not use this module to make decisions, so substituting a different
  Elixir module for coordinating interactions is perfectly fine. This module passes everything on
  to the Archetypes system. The only exception is input processing, which is passed to the
  Commands system.

  TODO: move the command system to a Plug-like process so souls and aliasing can be added
  fairly easily.
  """

  alias Militerm.ECS.Entity

  use Militerm.ECS.Entity

  alias Militerm.Systems.Archetypes

  defdelegate handle_event(entity_id, event, role, event_args), to: Archetypes, as: :execute_event
  defdelegate can?(entity_id, event, role, event_args), to: Archetypes, as: :ability
  defdelegate is?(entity_id, event, event_args), to: Archetypes, as: :trait
  defdelegate calculates?(entity_id, path), to: Archetypes, as: :calculates?
  defdelegate validates?(entity_id, path), to: Archetypes, as: :validates?
  defdelegate calculate(entity_id, path, args), to: Archetypes, as: :calculate
  defdelegate validate(entity_id, path, value, args), to: Archetypes, as: :validate

  def process_input(entity_id, input, context) do
    case Militerm.Systems.Commands.perform({:thing, entity_id}, input, context) do
      {:ok, new_context} -> new_context
      _ -> context
    end
  end
end

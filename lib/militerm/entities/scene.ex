defmodule Militerm.Entities.Scene do
  @moduledoc """
  This module manages interactions across components and systems for scenes. For most games,
  this will be sufficient when combined with the archetype and mixin scripts.

  N.B.: The core game engine does not use this module to make decisions, so substituting a different
  Elixir module for coordinating interactions is perfectly fine. This module passes everything on
  to the Archetypes system.
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

  def process_input(_entity_id, _input, context) do
    # we don't do anything with input
    context
  end
end

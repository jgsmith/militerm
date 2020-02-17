defmodule Militerm.Test.Scene do
  @moduledoc """
  The test entity module provides a simple archetype-based entity that allows the capture
  of output and provisioning of input to test scripts and environments.
  """

  use Militerm.ECS.Entity

  alias Militerm.Systems.Archetypes

  defdelegate handle_event(entity_id, event, role, event_args), to: Archetypes, as: :execute_event
  defdelegate can?(entity_id, event, role, event_args), to: Archetypes, as: :ability
  defdelegate is?(entity_id, event, event_args), to: Archetypes, as: :trait
  defdelegate calculates?(entity_id, path), to: Archetypes, as: :calculates?
  defdelegate validates?(entity_id, path), to: Archetypes, as: :validates?
  defdelegate calculate(entity_id, path, args), to: Archetypes, as: :calculate
  defdelegate validate(entity_id, path, value, args), to: Archetypes, as: :validate

  @doc """
  Sets up a new entity with the given archetype. Returns the entity identifier.
  """
  def new(entity_id, archetype, data) do
    create(entity_id, archetype, data)

    entity = {:thing, entity_id}
    # register a controlling interface
    {:ok, _} = Militerm.Test.Interface.start_link(entity)

    entity
  end

  def handle_event(entity_id, event, role, event_args) do
    Militerm.Test.Interface.log_event(entity_id, event, role, event_args)

    Archetypes.execute_event(entity_id, event, role, event_args)
  end

  def get_events(entity) do
    Militerm.Test.Interface.get_events(entity)
  end

  def clear_events(entity) do
    Militerm.Test.Interface.clear_events(entity)
  end

  @doc """
  Waiting for a known event to fire is a reasonable way to know when most processing of a command
  is completed.
  """
  def await_event(entity, event) do
    Militerm.Test.Interface.await_event(entity, event)
  end
end

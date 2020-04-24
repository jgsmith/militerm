defmodule Militerm.Components.Timers do
  use Militerm.ECS.EctoComponent,
    default: %{epoch: nil, timers: []},
    schema: Militerm.Data.Timers

  @moduledoc """
  The timers component manages timers that need to be active while an entity is active.

  Loading and saving and other management is done through the entity controller rather than
  through the data component.
  """

  def hibernate(_entity_id), do: :ok
  def unhibernate(_entity_id), do: :ok
end

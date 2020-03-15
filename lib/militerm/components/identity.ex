defmodule Militerm.Components.Identity do
  use Militerm.ECS.EctoComponent,
    default: %{name: nil},
    schema: Militerm.Data.Identity

  alias Militerm.English

  @moduledoc """
  The identity component manages identity of NPCs and other mobiles that have a social identity.
  For now, this is just the entity's name.
  """

  def hibernate(_entity_id), do: :ok
  def unhibernate(_entity_id), do: :ok
end

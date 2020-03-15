defmodule Militerm.Services.Characters do
  @moduledoc """
  Manages supervising character processes. Enters and exits, etc.

  We use Swarm to manage processes.

  The count of in-game players is per-node, so we don't consolidate counts across
  nodes and report that out through Prometheus. This makes it easier to manage since if a
  node goes down, it's count should go to zero, and then increase when it comes back up and
  players log in to the new node.
  """

  def enter_game(entity_id, opts \\ []) do
    receiver = Keyword.fetch!(opts, :receiver)

    Militerm.Systems.Entity.unhibernate(entity_id)
    Militerm.Systems.Entity.register_interface(entity_id, receiver)
    # TODO: increment player count in-game

    Militerm.Systems.Entity.event(entity_id, "enter:game", "actor", %{
      "this" => entity_id,
      "actor" => [entity_id]
    })
  end

  def leave_game(entity_id) do
    # TODO: decrement player count in-game
    Militerm.Systems.Entity.event(entity_id, "leave:game", "actor", %{
      "this" => entity_id,
      "actor" => [entity_id]
    })

    Militerm.Systems.Entity.unregister_interface(entity_id)
    Militerm.Systems.Entity.hibernate(entity_id)
  end

  def list_characters() do
    Swarm.registered()
    |> Enum.filter(fn
      {{:character, _}, _} -> true
      _ -> false
    end)
    |> Enum.map(fn {{:character, name}, _} -> name end)
  end
end

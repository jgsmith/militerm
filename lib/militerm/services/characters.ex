defmodule Militerm.Services.Characters do
  @moduledoc """
  Manages supervising character processes. Enters and exits, etc.

  We use Swarm to manage processes.

  The count of in-game players is per-node, so we don't consolidate counts across
  nodes and report that out through Prometheus. This makes it easier to manage since if a
  node goes down, it's count should go to zero, and then increase when it comes back up and
  players log in to the new node.
  """

  alias Militerm.Accounts

  def enter_game({:thing, entity_id} = entity, opts \\ []) do
    receiver = Keyword.fetch!(opts, :receiver)

    %{cap_name: cap_name} = Accounts.get_character(entity_id: entity_id)

    Militerm.Systems.Entity.unhibernate(entity)
    Militerm.Systems.Entity.register_interface(entity, receiver)

    Militerm.Systems.Entity.event(entity, "enter:game", "actor", %{
      "this" => entity,
      "actor" => [entity]
    })

    {:ok, entity_pid} = Militerm.Systems.Entity.whereis(entity)

    Swarm.join(:players, entity_pid)
    Militerm.Systems.Gossip.player_sign_in(cap_name)
  end

  def leave_game({:thing, entity_id} = entity) do
    {:ok, entity_pid} = Militerm.Systems.Entity.whereis(entity)
    %{cap_name: cap_name} = Accounts.get_character(entity_id: entity_id)

    Militerm.Systems.Gossip.player_sign_out(cap_name)
    Swarm.leave(:players, entity_pid)

    Militerm.Systems.Entity.event(entity, "leave:game", "actor", %{
      "this" => entity,
      "actor" => [entity]
    })

    Militerm.Systems.Entity.unregister_interface(entity)
    Militerm.Systems.Entity.hibernate(entity)
  end

  def list_characters() do
    :players
    |> Swarm.members()
    |> Enum.filter(fn pid -> pid != self() end)
    |> Enum.map(&Militerm.Systems.Entity.whatis/1)
  end
end

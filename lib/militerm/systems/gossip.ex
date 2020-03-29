defmodule Militerm.Systems.Gossip do
  @moduledoc """
  Provides a system interface between the Gossip network and the game.
  """
  use Militerm.ECS.System
  alias Militerm.Systems.{Entity, Events}

  defcommand who([]), for: %{"this" => {:thing, this_id} = this} = args do
    players =
      [this_id | Militerm.Services.Characters.list_characters()]
      |> Enum.map(fn entity_id ->
        case Militerm.Components.Identity.get(entity_id) do
          %{"name" => name} -> name
          _ -> "Someone"
        end
      end)
      |> Enum.sort()

    Entity.receive_message(
      this,
      "cmd",
      "There are #{Enum.count(players)} player(s): #{Enum.join(players, ", ")}"
    )
  end

  def player_sign_in(game_name, player_name) do
    Swarm.publish(:players, {:gossip_player_sign_in, game_name, player_name})
    :ok
  end

  def player_sign_out(game_name, player_name) do
    Swarm.publish(:players, {:gossip_player_sign_out, game_name, player_name})
    :ok
  end

  def player_sign_in(player_name) do
    Swarm.publish(:players, {:gossip_player_sign_in, player_name})
    Militerm.Gossip.Process.player_sign_in(player_name)
  end

  def player_sign_out(player_name) do
    Swarm.publish(:players, {:gossip_player_sign_out, player_name})
    Militerm.Gossip.Process.player_sign_out(player_name)
  end

  def tell_receive(from_game, from_player, to_player, message) do
    case Accounts.get_character(name: String.downcase(String.trim(to_player))) do
      {:ok, %{entity_id: entity_id}} ->
        Militerm.Systems.Events.trigger(entity_id, "gossip:tell", "player", %{
          "game" => from_game,
          "player" => from_player,
          "message" => message
        })

      _ ->
        :ok
    end
  end

  def game_connect(game_name) do
    Swarm.publish(:players, {:gossip_game_up, game_name})
    :ok
  end

  def game_disconnect(game_name) do
    Swarm.publish(:players, {:gossip_game_down, game_name})
    :ok
  end
end

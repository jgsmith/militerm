defmodule Militerm.Systems.Gossip do
  @moduledoc """
  Provides a system interface between the Gossip network and the game.
  """
  use Militerm.ECS.System
  alias Militerm.Systems.{Entity}
  alias Militerm.{Accounts, English}

  defcommand who(bits), for: %{"this" => this} = args do
    do_who_command(bits, this)
  end

  def do_who_command("", {:thing, this_id} = this) do
    players =
      [this_id | Militerm.Services.Characters.list_characters()]
      |> Enum.map(fn entity_id ->
        case Militerm.Components.Identity.get(entity_id) do
          %{"name" => name} -> name
          _ -> "Someone"
        end
      end)
      |> Enum.sort()

    case players do
      [] ->
        Entity.receive_message(
          this,
          "cmd",
          "There no players:"
        )

      [_] ->
        Entity.receive_message(
          this,
          "cmd",
          "There is one player: #{Enum.join(players, ", ")}"
        )

      _ ->
        Entity.receive_message(
          this,
          "cmd",
          "There are #{English.cardinal(Enum.count(players))} players: #{Enum.join(players, ", ")}"
        )
    end
  end

  def do_who_command(<<"@", game_name::binary>>, this) do
    # get the player list for a game
    lc_game_name = String.downcase(game_name)

    record =
      Gossip.who()
      |> Enum.find(fn {name, _} ->
        String.downcase(name) == lc_game_name
      end)

    {real_game_name, players} =
      case record do
        {_, _} -> record
        _ -> {game_name, []}
      end

    case players do
      [] ->
        Entity.receive_message(
          this,
          "cmd",
          "There are no players on #{real_game_name}:"
        )

      [_] ->
        Entity.receive_message(
          this,
          "cmd",
          "There is one player on #{real_game_name}: #{Enum.join(players, ", ")}"
        )

      _ ->
        Entity.receive_message(
          this,
          "cmd",
          "There are #{English.cardinal(Enum.count(players))} players on #{real_game_name}: #{
            Enum.join(Enum.sort(players), ", ")
          }"
        )
    end
  end

  def do_who_command(_, this) do
    Entity.receive_message(
      this,
      "cmd:error",
      "Use @who with no argument or with the name of a mud preceded by an @ (for example, '@who @somemud')."
    )
  end

  defscript gossip_channel_broadcast(channel, message), for: %{"this" => {:thing, entity_id}} do
    case Militerm.Components.Identity.get(entity_id) do
      %{"name" => name} ->
        Gossip.broadcast(channel, %{name: name, message: message})
        true

      _ ->
        false
    end
  end

  defscript gossip_tell(target_game, target_player, message),
    for: %{"this" => {:thing, entity_id}} do
    if player_at_game?(String.downcase(target_game), String.downcase(target_player)) do
      case Militerm.Components.Identity.get(entity_id) do
        %{"name" => name} ->
          Gossip.send_tell(target_player, target_game, name, message)
          true

        _ ->
          false
      end
    else
      false
    end
  end

  def player_at_game?(target_game, target_player) do
    {_, players} =
      Gossip.who()
      |> Enum.find({nil, []}, fn {name, _} ->
        String.downcase(name) == target_game
      end)

    Enum.any?(players, fn name ->
      String.downcase(name) == target_player
    end)
  end

  def players() do
    Militerm.Services.Characters.list_characters()
    |> Enum.map(fn entity_id ->
      case Militerm.Components.Identity.get(entity_id) do
        %{"name" => name} -> name
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
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

  def message_broadcast(game, player, channel, message) do
    Swarm.publish(:players, {:gossip_channel_broadcast, game, player, channel, message})
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

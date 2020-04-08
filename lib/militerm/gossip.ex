defmodule Militerm.Gossip do
  @moduledoc """
  Callback module to support the Gossip protocol.
  """

  require Logger

  @behaviour Gossip.Client.Core
  @behaviour Gossip.Client.Players
  @behaviour Gossip.Client.Tells
  @behaviour Gossip.Client.Games

  @impl true
  def user_agent() do
    Militerm.version()
  end

  @impl true
  def channels() do
    ["gossip", "testing"]
  end

  @impl true
  def players() do
    []
  end

  @impl true
  def authenticated(), do: :ok

  @impl true
  def message_broadcast(message) do
    Logger.info(fn ->
      "Gossip - message broadcast #{inspect(message)}"
    end)

    case message do
      %{channel: channel, game: from_game, message: message, name: player} ->
        Militerm.Systems.Gossip.message_broadcast(from_game, player, channel, message)

      _ ->
        :ok
    end
  end

  @impl true
  def player_sign_in(game_name, player_name) do
    Logger.info(fn ->
      "Gossip - new player sign in #{player_name}@#{game_name}"
    end)

    Militerm.Systems.Gossip.player_sign_in(game_name, player_name)
  end

  @impl true
  def player_sign_out(game_name, player_name) do
    Logger.info(fn ->
      "Gossip - new player sign out #{player_name}@#{game_name}"
    end)

    Militerm.Systems.Gossip.player_sign_out(game_name, player_name)
  end

  @impl true
  def player_update(game_name, player_names) do
    Logger.debug(fn ->
      "Gossip - received update for #{inspect(player_names)} @#{game_name}"
    end)
  end

  @impl true
  def tell_receive(from_game, from_player, to_player, message) do
    Logger.info(fn ->
      "Gossip - received tell from #{from_player}@#{from_game} for #{to_player}"
    end)

    Militerm.Systems.Gossip.tell_receive(from_game, from_player, to_player, message)

    :ok
  end

  @impl true
  def game_update(_game), do: :ok

  @impl true
  def game_connect(game) do
    Logger.info(fn ->
      "Gossip - #{game} up"
    end)

    Militerm.Systems.Gossip.game_connect(game)
  end

  @impl true
  def game_disconnect(game) do
    Logger.info(fn ->
      "Gossip - #{game} down"
    end)

    Militerm.Systems.Gossip.game_disconnect(game)
  end
end

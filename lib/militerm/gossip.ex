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
    []
  end

  @impl true
  def players() do
    []
  end

  @impl true
  def authenticated(), do: :ok

  @impl true
  def message_broadcast(message) do
    :ok
  end

  @impl true
  def player_sign_in(game_name, player_name) do
    Logger.info(fn ->
      "Gossip - new player sign in #{player_name}@#{game_name}"
    end)

    :ok
  end

  @impl true
  def player_sign_out(game_name, player_name) do
    Logger.info(fn ->
      "Gossip - new player sign out #{player_name}@#{game_name}"
    end)

    :ok
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

    # find the entity id for the character and trigger an async event
    :ok
  end

  @impl true
  def game_update(_game), do: :ok

  @impl true
  def game_connect(_game), do: :ok

  @impl true
  def game_disconnect(_game), do: :ok
end

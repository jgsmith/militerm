defmodule Militerm.Gossip.Process do
  @moduledoc """
  Uses Swarm to ensure the Gossip process is running on one node rather than all nodes.
  """

  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end

  def subscribe(channel) do
    maybe_call({:subscribe, channel})
  end

  def unsubscribe(channel) do
    maybe_call({:unsubscribe, channel})
  end

  def broadcast(channel, message) do
    maybe_call({:broadcast, channel, message})
  end

  def player_sign_in(player_name) do
    maybe_call({:sign_in, player_name})
  end

  def player_sign_out(player_name) do
    maybe_call({:sign_out, player_name})
  end

  def send_tell(sending_player, game_name, player_name, message) do
    maybe_call({:send_tell, sending_player, game_name, player_name, message})
  end

  def who(), do: maybe_call(:who)

  def games(), do: maybe_call(:games)

  def init(_) do
    Process.send_after(self(), :start_gossip, 0)
    {:ok, nil}
  end

  @impl true
  def handle_info(:start_gossip, state) do
    {:ok, _} = Application.ensure_all_started(:gossip)
    {:noreply, state}
  end

  @impl true
  def handle_info({:swarm, :die}, state) do
    Application.stop(:gossip)
    {:stop, :shutdown, state}
  end

  @impl true
  def handle_cast({:swarm, :end_handoff, state}, _state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:swarm, :resolve_conflict, state}, _state) do
    {:noreply, state}
  end

  @impl true
  def handle_call({:swarm, :begin_handoff}, _from, state) do
    Application.stop(:gossip)
    {:reply, {:resume, state}, state}
  end

  def handle_call(:shutdown, _from, state) do
    Application.stop(:gossip)
    {:stop, :shutdown, state}
  end

  def handle_call({:subscribe, channel}, _from, state) do
    {:reply, Gossip.subscribe(channel), state}
  end

  def handle_call({:unsubscribe, channel}, _from, state) do
    {:reply, Gossip.unsubscribe(channel), state}
  end

  def handle_call({:broadcast, channel, message}, _from, state) do
    {:reply, Gossip.broadcast(channel, message), state}
  end

  def handle_call({:sign_in, player_name}, _from, state) do
    {:reply, Gossip.player_sign_in(player_name), state}
  end

  def handle_call({:sign_out, player_name}, _from, state) do
    {:reply, Gossip.player_sign_out(player_name), state}
  end

  def handle_call({:send_tell, sending_player, game_name, player_name, message}, _from, state) do
    {:reply, Gossip.send_tell(sending_player, game_name, player_name, message), state}
  end

  def handle_call(:who, _from, state) do
    {:reply, Gossip.who(), state}
  end

  def handle_call(:games, _from, state) do
    {:reply, Gossip.games(), state}
  end

  defp maybe_call(message) do
    case Swarm.whereis_name(Gossip) do
      pid when is_pid(pid) -> GenServer.call(pid, message)
      _ -> nil
    end
  end
end

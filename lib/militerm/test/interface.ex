defmodule Militerm.Test.Interface do
  @moduledoc """
  The test interface provides for the capture and injection of output and input for a controlled
  entity.
  """

  use GenServer

  def start_link({:thing, _} = entity) do
    GenServer.start_link(__MODULE__, [entity], name: {:global, {:interface, entity}})
  end

  def log_event(entity_id, event, role, event_args) do
    GenServer.cast(
      {:global, {:interface, {:thing, entity_id}}},
      {:event, event, role, event_args}
    )
  end

  def receive_message(pid, msg_class, message) do
    GenServer.cast(pid, {:receive_message, msg_class, message})
  end

  def get_events(entity) do
    GenServer.call({:global, {:interface, entity}}, :get_events)
  end

  def clear_events(entity) do
    GenServer.call({:global, {:interface, entity}}, :clear_events)
  end

  def await_event(entity, event) do
    GenServer.call({:global, {:interface, entity}}, {:await_event, event})
  end

  def get_output(entity) do
    GenServer.call({:global, {:interface, entity}}, :get_output)
  end

  def clear_output(entity) do
    GenServer.call({:global, {:interface, entity}}, :clear_output)
  end

  def init([entity]) do
    Process.send_after(self(), :register_interface, 0)

    {:ok,
     %{
       entity: entity,
       received: [],
       events: [],
       awaited_events: []
     }}
  end

  def handle_info(:register_interface, %{entity: entity} = state) do
    Militerm.Systems.Entity.register_interface(entity, __MODULE__)
    {:noreply, state}
  end

  def handle_cast({:receive_message, message_type, message}, %{received: received} = state) do
    {:noreply, %{state | received: [{message_type, message} | received]}}
  end

  def handle_cast(
        {:event, event, role, event_args},
        %{events: events, awaited_events: awaiting} = state
      ) do
    new_awaiting =
      awaiting
      |> Enum.filter(fn {from, e} ->
        if e == event do
          GenServer.reply(from, :ok)
        else
          true
        end
      end)

    {:noreply,
     %{state | events: [{event, role, event_args} | events], awaited_events: new_awaiting}}
  end

  def handle_call(
        {:await_event, event},
        from,
        %{events: events, awaited_events: awaiting} = state
      ) do
    if Enum.any?(events, fn {e, _, _} -> e == event end) do
      {:reply, :ok, state}
    else
      {:noreply, %{state | awaited_events: [{from, event} | awaiting]}}
    end
  end

  def handle_call(:get_output, _from, %{received: received} = state) do
    {:reply, Enum.reverse(received), state}
  end

  def handle_call(:clear_output, _from, state) do
    {:reply, :ok, %{state | received: []}}
  end

  def handle_call(:get_events, _from, %{events: events} = state) do
    {:reply, Enum.reverse(events), state}
  end

  def handle_call(:clear_events, _from, state) do
    {:reply, :ok, %{state | events: []}}
  end
end

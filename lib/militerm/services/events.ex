defmodule Militerm.Services.Events do
  @moduledoc """
  Provides an event reflector for async events. 
  """

  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def child_spec(opts \\ []) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[{:name, __MODULE__} | opts]]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def queue_event(entity_id, event, role, args) do
    GenServer.cast(__MODULE__, {:trigger_event, entity_id, event, role, args})
  end

  ###
  ### Callbacks
  ###

  @impl true
  def init(_) do
    store = %{}
    # init store by reading in verbs from filesystem - asyn from this, of course
    {:ok, %{}}
  end

  def handle_cast({:trigger_event, {:thing, _} = entity, event, role, args}, state) do
    Militerm.Systems.Entity.event(entity, event, role, args)
    {:noreply, state}
  end

  def handle_cast({:trigger_event, {:thing, _, _} = entity, event, role, args}, state) do
    Militerm.Systems.Entity.event(entity, event, role, args)
    {:noreply, state}
  end

  def handle_cast({:trigger_event, entity_id, event, role, args}, state) do
    Militerm.Systems.Entity.event({:thing, entity_id}, event, role, args)
    {:noreply, state}
  end
end

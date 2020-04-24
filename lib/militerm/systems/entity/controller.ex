defmodule Militerm.Systems.Entity.Controller do
  use GenServer

  alias Militerm.Config
  alias Militerm.Systems.MML

  alias Militerm.Systems.Entity

  @moduledoc """
  Manages control of an entity -- managing events more than anything else.
  """

  def start_link(entity_id, entity_module) do
    GenServer.start_link(__MODULE__, [entity_id, entity_module])
  end

  def child_spec(opts \\ []) do
    entity_id = Keyword.fetch!(opts, :entity_id)
    entity_module = Keyword.fetch!(opts, :entity_module)

    %{
      id: {:via, :swarm, entity_id},
      start: {__MODULE__, :start_link, [entity_id, entity_module]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  ###
  ### Public API
  ###

  def set_property({:thing, entity_id, coord}, ["detail", "default" | path], value, args)
      when is_binary(coord) do
    set_property(
      {:thing, entity_id},
      ["detail", coord | path],
      value,
      Map.put(args, "coord", coord)
    )
  end

  def set_property({:thing, entity_id, coord}, path, value, args) do
    set_property({:thing, entity_id}, path, value, Map.put(args, "coord", coord))
  end

  def set_property({:thing, entity_id} = thing, [component | path] = full_path, value, args) do
    bin_path = full_path |> Enum.reverse() |> Enum.join(":")

    validated_value =
      if validates?(thing, bin_path) do
        validate(thing, bin_path, value, args)
      else
        value
      end

    old_value = property(thing, full_path, args)

    if is_nil(validated_value) do
      old_value
    else
      component_atom = String.to_existing_atom(component)

      case Map.fetch(Militerm.Config.master().components(), component_atom) do
        {:ok, module} ->
          module.set_value(entity_id, path, validated_value)

          if old_value != validated_value do
            # trigger change event
            event = "change:#{Enum.join(full_path, ":")}"

            Militerm.Systems.Events.trigger(entity_id, event, %{
              "observed" => [thing],
              "prior" => old_value,
              "value" => validated_value
            })
          end

        _ ->
          nil
      end
    end
  end

  def set_property(_, _, _, _), do: nil

  def reset_property({:thing, entity_id, coord}, ["detail", "default" | path], args)
      when is_binary(coord) do
    reset_property({:thing, entity_id}, ["detail", coord | path], Map.put(args, "coord", coord))
  end

  def reset_property({:thing, entity_id, coord}, path, args) do
    reset_property({:thing, entity_id}, path, Map.put(args, "coord", coord))
  end

  def reset_property({:thing, entity_id}, [component | path], args) do
    component_atom = String.to_existing_atom(component)

    case Map.fetch(Militerm.Config.master().components(), component_atom) do
      {:ok, module} ->
        module.reset_value(entity_id, path)

      _ ->
        nil
    end
  end

  def reset_property(_, _, _), do: nil

  def remove_property({:thing, entity_id, coord}, ["detail", "default" | path])
      when is_binary(coord) do
    remove_property({:thing, entity_id}, ["detail", coord | path])
  end

  def remove_property({:thing, entity_id, coord}, path) do
    remove_property({:thing, entity_id}, path)
  end

  def remove_property({:thing, entity_id}, [component | path]) do
    component_atom = String.to_existing_atom(component)

    case Map.fetch(Militerm.Config.master().components(), component_atom) do
      {:ok, module} ->
        module.remove_value(entity_id, path)

      _ ->
        nil
    end
  end

  def property({:thing, entity_id, coord}, ["raw", "detail", "default" | path], args)
      when is_binary(coord) do
    property(
      {:thing, entity_id},
      ["raw", "detail", coord | path],
      Map.put(args, "coord", coord)
    )
  end

  def property({:thing, entity_id, coord}, ["detail", "default" | path], args)
      when is_binary(coord) do
    property({:thing, entity_id}, ["detail", coord | path], Map.put(args, "coord", coord))
  end

  def property({:thing, entity_id, coord}, path, args) do
    property({:thing, entity_id}, path, Map.put(args, "coord", coord))
  end

  def property(this, ["raw" | path], args), do: raw_property(this, path, args)

  def property({:thing, entity_id} = this, full_path, args) do
    # we're just reading, so no need to forward to the GenServer
    bin_path = full_path |> Enum.join(":")

    if calculates?(this, bin_path) do
      calculate(this, bin_path, args)
    else
      raw_property(this, full_path, args)
    end
  end

  def property(_, _, _), do: nil

  def raw_property({:thing, entity_id}, [component | path], _args) do
    component_atom = String.to_existing_atom(component)

    case Map.fetch(Militerm.Config.master().components(), component_atom) do
      {:ok, module} ->
        module.get_value(entity_id, path)

      _ ->
        nil
    end
  end

  def calculates?({:thing, entity_id}, path) do
    case Militerm.Components.Entity.module(entity_id) do
      {:ok, module} ->
        apply(module, :calculates?, [entity_id, path])

      _ ->
        false
    end
  end

  def calculate({:thing, entity_id}, path, args) do
    case Militerm.Components.Entity.module(entity_id) do
      {:ok, module} ->
        apply(module, :calculate, [entity_id, path, args])

      _ ->
        nil
    end
  end

  def pre_event({:thing, entity_id, coord}, event, role, args) do
    pre_event({:thing, entity_id}, event, role, Map.put(args, "coord", coord))
  end

  def pre_event({:thing, entity_id} = entity, event, role, args) do
    case Militerm.Components.Entity.module(entity_id) do
      {:ok, module} ->
        apply(module, :handle_event, [entity_id, "pre-" <> event, role, args])

      _ ->
        false
    end
  end

  def pre_event(_, _, _, _), do: false

  def event({:thing, entity_id, coord}, event, role, args) do
    event({:thing, entity_id}, event, role, Map.put(args, "coord", coord))
  end

  def event({:thing, entity_id} = entity, event, role, args) do
    case Militerm.Components.Entity.module(entity_id) do
      {:ok, module} ->
        apply(module, :handle_event, [entity_id, event, role, args])

      _ ->
        nil
    end
  end

  def event(_, _, _, _), do: nil

  @doc """
  Returns a task that can be joined, if needed.
  """
  def async_event({:thing, entity_id, coord}, event, role, args) do
    async_event({:thing, entity_id}, event, role, Map.put(args, "coord", coord))
  end

  def async_event({:thing, entity_id} = entity, event, role, args) do
    case Militerm.Components.Entity.module(entity_id) do
      {:ok, module} ->
        Task.start(module, :handle_event, [entity_id, event, role, args])

      _ ->
        nil
    end
  end

  def async_event(_, _, _, _), do: nil

  def post_event({:thing, entity_id, coord}, event, role, args) do
    post_event({:thing, entity_id}, event, role, Map.put(args, "coord", coord))
  end

  def post_event({:thing, entity_id} = entity, event, role, args) do
    case Militerm.Components.Entity.module(entity_id) do
      {:ok, module} ->
        apply(module, :handle_event, [entity_id, "post-" <> event, role, args])

      _ ->
        nil
    end
  end

  def post_event(_, _, _, _), do: nil

  def can?({:thing, entity_id, coord}, ability, role, args) do
    can?({:thing, entity_id}, ability, role, Map.put(args, "coord", coord))
  end

  def can?({:thing, entity_id} = entity, ability, role, args) do
    case Militerm.Components.Entity.module(entity_id) do
      {:ok, module} ->
        apply(module, :can?, [entity_id, ability, role, args])

      _ ->
        false
    end
  end

  def can?(_, _, _, _), do: false

  def is?(thing, trait, args \\ %{})

  def is?({:thing, entity_id, coord}, trait, args) do
    is?({:thing, entity_id}, trait, Map.put(args, "coord", coord))
  end

  def is?({:thing, entity_id} = entity, trait, args) do
    case Militerm.Components.Entity.module(entity_id) do
      {:ok, module} ->
        apply(module, :is?, [entity_id, trait, args])

      _ ->
        false
    end
  end

  def is?(_, _, _), do: false

  def validates?({:thing, entity_id} = entity, path) do
    case Militerm.Components.Entity.module(entity_id) do
      {:ok, module} ->
        apply(module, :validates?, [entity_id, path])

      _ ->
        false
    end
  end

  def validate({:thing, entity_id} = entity, path, value, args) do
    case Militerm.Components.Entity.module(entity_id) do
      {:ok, module} ->
        apply(module, :validate, [entity_id, path, value, args])

      _ ->
        false
    end
  end

  def add_recurring_timer({:thing, entity_id, coord}, delay, event, args) do
    add_recurring_timer({:thing, entity_id}, delay, event, Map.put(args, "coord", coord))
  end

  def add_recurring_timer({:thing, entity_id} = entity, delay, event, args) do
    case Entity.whereis(entity) do
      {:ok, pid} ->
        GenServer.call(pid, {:add_recurring_timer, delay, event, args})

      _ ->
        nil
    end
  end

  def add_delayed_timer({:thing, entity_id, coord}, delay, event, args) do
    add_delayed_timer({:thing, entity_id}, delay, event, Map.put(args, "coord", coord))
  end

  def add_delayed_timer({:thing, entity_id} = entity, delay, event, args) do
    case Entity.whereis(entity) do
      {:ok, pid} ->
        GenServer.call(pid, {:add_delayed_timer, delay, event, args})

      _ ->
        nil
    end
  end

  def remove_timer(_, nil), do: false

  def remove_timer({:thing, entity_id} = entity, timer_id) do
    case Entity.whereis(entity) do
      {:ok, pid} ->
        GenServer.call(pid, {:remove_timer, timer_id})

      _ ->
        false
    end
  end

  ###
  ### Implementation
  ###

  @impl true
  def init([entity_id, entity_module]) do
    {:ok,
     %{
       module: entity_module,
       entity_id: entity_id,
       context: %{actor: {:thing, entity_id}},
       interfaces: [],
       epoch: DateTime.to_unix(DateTime.utc_now()),
       timers: PriorityQueue.new(),
       next_timer: nil,
       last_timer_id: 1
     }}
  end

  @impl true
  def handle_info({:swarm, :die}, state) do
    {:stop, :shutdown, state}
  end

  def handle_info(
        {:gossip_player_sign_in, game, player},
        %{module: module, entity_id: entity_id} = state
      ) do
    apply(module, :handle_event, [
      entity_id,
      "gossip:player:sign_in",
      "player",
      %{"game" => game, "player" => player}
    ])

    {:noreply, state}
  end

  def handle_info(
        {:gossip_player_sign_out, game, player},
        %{module: module, entity_id: entity_id} = state
      ) do
    apply(module, :handle_event, [
      entity_id,
      "gossip:player:sign_out",
      "player",
      %{"game" => game, "player" => player}
    ])

    {:noreply, state}
  end

  def handle_info(
        {:gossip_player_sign_in, player},
        %{module: module, entity_id: entity_id} = state
      ) do
    apply(module, :handle_event, [
      entity_id,
      "local:player:sign_in",
      "player",
      %{"player" => player}
    ])

    {:noreply, state}
  end

  def handle_info(
        {:gossip_player_sign_out, player},
        %{module: module, entity_id: entity_id} = state
      ) do
    apply(module, :handle_event, [
      entity_id,
      "local:player:sign_out",
      "player",
      %{"player" => player}
    ])

    {:noreply, state}
  end

  def handle_info(
        {:gossip_channel_broadcast, game, player, channel, message},
        %{module: module, entity_id: entity_id} = state
      ) do
    apply(module, :handle_event, [
      entity_id,
      "gossip:channel:broadcast",
      "player",
      %{"game" => game, "player" => player, "channel" => channel, "message" => message}
    ])

    {:noreply, state}
  end

  def handle_info({:gossip_game_up, game}, %{module: module, entity_id: entity_id} = state) do
    apply(module, :handle_event, [entity_id, "gossip:game:up", "player", %{"game" => game}])
    {:noreply, state}
  end

  def handle_info({:gossip_game_down, game}, %{module: module, entity_id: entity_id} = state) do
    apply(module, :handle_event, [entity_id, "gossip:game:down", "player", %{"game" => game}])
    {:noreply, state}
  end

  def handle_info(:process_timers, %{epoch: epoch, timers: timers, entity_id: entity_id} = state) do
    remaining_timers =
      process_current_timers(timers, entity_id, DateTime.to_unix(DateTime.utc_now()) - epoch)

    next_timer =
      case PriorityQueue.min(remaining_timers) do
        {epoch_time, _} when not is_nil(epoch_time) ->
          delta = max(epoch_time - DateTime.to_unix(DateTime.utc_now()) + epoch, 0)

          Process.send_after(self(), :process_timers, delta * 1000)

        _ ->
          nil
      end

    {:noreply, store_timer_state(%{state | next_timer: next_timer, timers: remaining_timers})}
  end

  @impl true
  def handle_cast({:swarm, :end_handoff, %{timers: timers, epoch: epoch} = state}, _state) do
    next_timer =
      case PriorityQueue.min(timers) do
        {epoch_time, _} when not is_nil(epoch_time) ->
          delta = max(epoch_time - DateTime.to_unix(DateTime.utc_now()) + epoch, 0)

          Process.send_after(self(), :process_timers, delta * 1000)

        _ ->
          nil
      end

    {:noreply, %{state | next_timer: next_timer}}
  end

  @impl true
  def handle_cast({:swarm, :resolve_conflict, state}, _state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:process_input, input},
        %{context: context, module: module, entity_id: entity_id} = state
      ) do
    new_context = apply(module, :process_input, [entity_id, input, context])

    {:noreply, %{state | context: new_context}}
  end

  @impl true
  def handle_call(
        :hibernate,
        _from,
        %{next_timer: next_timer} = state
      ) do
    if not is_nil(next_timer) do
      Process.cancel_timer(next_timer)
    end

    store_timer_state(state)

    {:reply, :ok, %{state | next_timer: nil}}
  end

  @impl true
  def handle_call(:unhibernate, _from, state) do
    {:reply, :ok, fetch_timer_state(state)}
  end

  @impl true
  def handle_call(
        {:process_input, input},
        _from,
        %{context: context, module: module, entity_id: entity_id} = state
      ) do
    new_context = apply(module, :process_input, [entity_id, input, context])

    {:reply, :ok, %{state | context: new_context}}
  end

# {:add_recurring_timer, 1, "consume:fuel", %{}
  def handle_call(
        {:add_recurring_timer, delta, event, args},
        _from,
        %{epoch: epoch, timers: timers, next_timer: next_timer, last_timer_id: last_timer_id} =
          state
      ) do
    if not is_nil(next_timer) do
      Process.cancel_timer(next_timer)
    end

    timer_id = last_timer_id + 1

    new_timers =
      handle_add_recurring_timers(timers, DateTime.to_unix(DateTime.utc_now()) - epoch, %{
        "event" => event,
        "args" => args,
        "every" => delta,
        "id" => timer_id
      })

    next_timer =
      case PriorityQueue.min(new_timers) do
        {epoch_time, _} when not is_nil(epoch_time) ->
          delta = max(epoch_time - DateTime.to_unix(DateTime.utc_now()) + epoch, 0)

          Process.send_after(self(), :process_timers, delta * 1000)

        _ ->
          nil
      end

    {:reply, timer_id,
     store_timer_state(%{
       state
       | timers: new_timers,
         next_timer: next_timer,
         last_timer_id: timer_id
     })}
  end

  def handle_call(
        {:add_delayed_timer, delay, event, args},
        _from,
        %{epoch: epoch, timers: timers, next_timer: next_timer, last_timer_id: last_timer_id} =
          state
      ) do
    if not is_nil(next_timer) do
      Process.cancel_timer(next_timer)
    end

    timer_id = last_timer_id + 1

    new_timers =
      handle_add_delayed_timer(timers, DateTime.to_unix(DateTime.utc_now()) - epoch + delay, %{
        "event" => event,
        "args" => args,
        "id" => timer_id
      })

    next_timer =
      case PriorityQueue.min(new_timers) do
        {epoch_time, _} when not is_nil(epoch_time) ->
          delta = max(epoch_time - DateTime.to_unix(DateTime.utc_now()) + epoch, 0)

          Process.send_after(self(), :process_timers, delta * 1000)

        _ ->
          nil
      end

    {:reply, timer_id,
     store_timer_state(%{
       state
       | timers: new_timers,
         next_timer: next_timer,
         last_timer_id: timer_id
     })}
  end

  def handle_call({:remove_timer, timer_id}, _from, %{timers: timers, next_timer: next_timer} = state) do
    new_timers = timers
      |> PriorityQueue.to_list
      |> Enum.reject(fn {_, %{"id" => id}} -> id == timer_id end)
      |> Enum.into(PriorityQueue.new())

    {:reply, true, store_timer_state(%{state | timers: new_timers})}
  end

  def handle_call(:get_entity_id, _from, %{entity_id: entity_id} = state) do
    {:reply, entity_id, state}
  end

  @impl true
  def handle_call(
        {:register_interface, module},
        {pid, _} = _from,
        %{interfaces: interfaces} = state
      ) do
    pair = {pid, module}

    if pair in interfaces do
      {:reply, :ok, state}
    else
      {:reply, :ok, %{state | interfaces: [{pid, module} | interfaces]}}
    end
  end

  @impl true
  def handle_call(:unregister_interface, {pid, _} = _from, %{interfaces: interfaces} = state) do
    remaining_interfaces =
      interfaces
      |> Enum.reject(fn
        {^pid, _} -> true
        _ -> false
      end)

    {:reply, :ok, %{state | interfaces: remaining_interfaces}}
  end

  @impl true
  def handle_call(:registered_interfaces, _from, %{interfaces: interfaces} = state) do
    {:reply, interfaces, state}
  end

  @impl true
  def handle_call(
        {:receive_message, message_type, message},
        _from,
        %{interfaces: interfaces} = state
      ) do
    for {pid, module} <- interfaces do
      apply(module, :receive_message, [pid, message_type, message])
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:swarm, :begin_handoff}, _from, %{next_timer: next_timer} = state) do
    if not is_nil(next_timer), do: Process.cancel_timer(next_timer)

    {:reply, {:resume, %{state | next_timer: nil}}, state}
  end

  def handle_call(:shutdown, state) do
    {:stop, :shutdown, state}
  end

  def handle_call(
        {:can, ability, role, args},
        _from,
        %{module: module, entity_id: entity_id} = state
      ) do
    {:reply, apply(module, :can?, [entity_id, ability, role, args]), state}
  end

  def handle_call(
        {:is, trait, args},
        _from,
        %{module: module, entity_id: entity_id} = state
      ) do
    {:reply, apply(module, :is?, [entity_id, trait, args]), state}
  end

  def handle_call(
        {:validates?, path},
        _from,
        %{module: module, entity_id: entity_id} = state
      ) do
    {:reply, apply(module, :validates?, [entity_id, path]), state}
  end

  def handle_call(
        {:validate, path, value, args},
        _from,
        %{module: module, entity_id: entity_id} = state
      ) do
    {:reply, apply(module, :validate, [entity_id, path, value, args]), state}
  end

  defp process_current_timers(timers, entity_id, epoch_now) do
    case PriorityQueue.min(timers) do
      {epoch_time, timer_info} when not is_nil(epoch_time) and epoch_time <= epoch_now ->
        run_timer(entity_id, timer_info)

        timers
        |> PriorityQueue.delete_min()
        |> handle_add_recurring_timers(epoch_now, timer_info)
        |> process_current_timers(entity_id, epoch_now)

      _ ->
        timers
    end
  end

  defp handle_remove_timer(timers, timer_id) do
    timers
    |> PriorityQueue.to_list()
    |> Enum.reject(fn {_, %{"timer_id" => id}} -> id == timer_id end)
    |> Enum.into(PriorityQueue.new())
  end

  defp handle_add_recurring_timers(timers, epoch_now, %{"every" => time_delta} = event) do
    PriorityQueue.put(timers, {epoch_now + time_delta, event})
  end

  defp handle_add_recurring_timers(timers, _, _), do: timers

  defp handle_add_delayed_timer(timers, epoch_time, event) do
    PriorityQueue.put(timers, {epoch_time, event})
  end

  def run_timer(entity_id, %{"event" => event, "args" => args} = timer_info) do
    Task.start fn ->
      Militerm.Systems.Entity.event({:thing, entity_id}, "timer:#{event}", "timer", args)
    end
  end

  def store_timer_state(%{entity_id: entity_id, epoch: epoch, timers: timer_queue} = state) do
    Militerm.Components.Timers.set(entity_id, %{
      epoch: DateTime.to_unix(DateTime.utc_now()) - epoch,
      timers: timer_queue
        |> PriorityQueue.to_list()
        |> Enum.map(fn
          {v, %{"args" => args} = map} ->
            {v, Map.put(map, "args",
              args
              |> :erlang.term_to_binary()
              |> Base.encode64(padding: false)
            )}
          entry -> entry
        end)
        |> Enum.map(&Tuple.to_list/1)
    })

    state
  end

  def fetch_timer_state(%{entity_id: entity_id} = state) do
    new_state =
      case Militerm.Components.Timers.get(entity_id) do
        nil ->
          state

        %{epoch: saved_epoch, timers: timer_list} ->
          timers = timer_list
            |> Enum.map(&List.to_tuple/1)
            |> Enum.map(fn
              {v, %{"args" => args} = map} ->
                {v, Map.put(map, "args",
                  args
                  |> Base.decode64!(padding: false)
                  |> :erlang.binary_to_term(:safe)
                )}
              entry -> entry
            end)
            |> Enum.into(PriorityQueue.new())
          epoch = DateTime.to_unix(DateTime.utc_now()) - saved_epoch

          next_timer =
            case PriorityQueue.min(timers) do
              {epoch_time, _} when not is_nil(epoch_time) ->
                delta = max(epoch_time - DateTime.to_unix(DateTime.utc_now()) + epoch, 0)

                Process.send_after(self(), :process_timers, delta * 1000)

              _ ->
                nil
            end

          %{state | epoch: saved_epoch, timers: timers, next_timer: next_timer}
      end
  end
end

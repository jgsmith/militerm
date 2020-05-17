defmodule Militerm.Systems.Entity.Timers do
  alias Militerm.Systems.Entity

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

  def init_data([entity_id, entity_module]) do
    %{
      epoch: DateTime.to_unix(DateTime.utc_now()),
      timers: PriorityQueue.new(),
      next_timer: nil,
      last_timer_id: 1
    }
  end

  def handle_process_timers(%{epoch: epoch, timers: timers, entity_id: entity_id} = state) do
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

    store_timer_state(%{state | next_timer: next_timer, timers: remaining_timers})
  end

  def handle_hibernate(state) do
    %{store_timer_state(state) | next_timer: nil}
  end

  def handle_unhibernate(state), do: fetch_timer_state(state)

  def handle_add_recurring_timer(
        delta,
        event,
        args,
        %{epoch: epoch, timers: timers, next_timer: next_timer, last_timer_id: last_timer_id} =
          state
      ) do
    if not is_nil(next_timer) do
      Process.cancel_timer(next_timer)
    end

    timer_id = last_timer_id + 1

    new_timers =
      int_add_recurring_timers(timers, DateTime.to_unix(DateTime.utc_now()) - epoch, %{
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

    {timer_id,
     store_timer_state(%{
       state
       | timers: new_timers,
         next_timer: next_timer,
         last_timer_id: timer_id
     })}
  end

  def handle_add_delayed_timer(
        delay,
        event,
        args,
        %{epoch: epoch, timers: timers, next_timer: next_timer, last_timer_id: last_timer_id} =
          state
      ) do
    if not is_nil(next_timer) do
      Process.cancel_timer(next_timer)
    end

    timer_id = last_timer_id + 1

    new_timers =
      int_add_delayed_timer(timers, DateTime.to_unix(DateTime.utc_now()) - epoch + delay, %{
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

    {timer_id,
     store_timer_state(%{
       state
       | timers: new_timers,
         next_timer: next_timer,
         last_timer_id: timer_id
     })}
  end

  def handle_remove_timer(timer_id, %{timers: timers, next_timer: next_timer} = state) do
    new_timers =
      timers
      |> PriorityQueue.to_list()
      |> Enum.reject(fn {_, %{"id" => id}} -> id == timer_id end)
      |> Enum.into(PriorityQueue.new())

    store_timer_state(%{state | timers: new_timers})
  end

  defp process_current_timers(timers, entity_id, epoch_now) do
    case PriorityQueue.min(timers) do
      {epoch_time, timer_info} when not is_nil(epoch_time) and epoch_time <= epoch_now ->
        run_timer(entity_id, timer_info)

        timers
        |> PriorityQueue.delete_min()
        |> int_add_recurring_timers(epoch_now, timer_info)
        |> process_current_timers(entity_id, epoch_now)

      _ ->
        timers
    end
  end

  defp int_remove_timer(timers, timer_id) do
    timers
    |> PriorityQueue.to_list()
    |> Enum.reject(fn {_, %{"timer_id" => id}} -> id == timer_id end)
    |> Enum.into(PriorityQueue.new())
  end

  defp int_add_recurring_timers(timers, epoch_now, %{"every" => time_delta} = event) do
    PriorityQueue.put(timers, {epoch_now + time_delta, event})
  end

  defp int_add_recurring_timers(timers, _, _), do: timers

  defp int_add_delayed_timer(timers, epoch_time, event) do
    PriorityQueue.put(timers, {epoch_time, event})
  end

  def run_timer(entity_id, %{"event" => event, "args" => args} = timer_info) do
    Task.start(fn ->
      Militerm.Systems.Entity.event({:thing, entity_id}, "timer:#{event}", "timer", args)
    end)
  end

  def store_timer_state(
        %{entity_id: entity_id, epoch: epoch, timers: timer_queue, last_timer_id: last_timer_id} =
          state
      ) do
    epoch = if is_nil(epoch), do: DateTime.to_unix(DateTime.utc_now()), else: epoch

    Militerm.Components.Timers.set(entity_id, %{
      "epoch" => DateTime.to_unix(DateTime.utc_now()) - epoch,
      "last_timer_id" => last_timer_id,
      "timers" =>
        timer_queue
        |> PriorityQueue.to_list()
        |> Enum.map(fn
          {v, %{"args" => args} = map} ->
            {v,
             Map.put(
               map,
               "args",
               args
               |> :erlang.term_to_binary()
               |> Base.encode64(padding: false)
             )}

          entry ->
            entry
        end)
        |> Enum.map(&Tuple.to_list/1)
    })

    state
  end

  def fetch_timer_state(%{entity_id: entity_id} = state) do
    new_state =
      case Militerm.Components.Timers.get(entity_id) do
        %{"epoch" => saved_epoch, "timers" => timer_list, "last_timer_id" => last_timer_id} = info ->
          timers =
            timer_list
            |> Enum.map(&List.to_tuple/1)
            |> Enum.map(fn
              {v, %{"args" => args} = map} ->
                {v,
                 Map.put(
                   map,
                   "args",
                   args
                   |> Base.decode64!(padding: false)
                   |> :erlang.binary_to_term(:safe)
                 )}

              entry ->
                entry
            end)
            |> Enum.into(PriorityQueue.new())

          epoch =
            if is_nil(saved_epoch) do
              DateTime.to_unix(DateTime.utc_now())
            else
              DateTime.to_unix(DateTime.utc_now()) - saved_epoch
            end

          next_timer =
            case PriorityQueue.min(timers) do
              {epoch_time, _} when not is_nil(epoch_time) ->
                delta = max(epoch_time - DateTime.to_unix(DateTime.utc_now()) + epoch, 0)

                Process.send_after(self(), :process_timers, delta * 1000)

              _ ->
                nil
            end

          %{
            state
            | epoch: saved_epoch,
              timers: timers,
              next_timer: next_timer,
              last_timer_id: last_timer_id
          }

        _ ->
          state
      end
  end
end

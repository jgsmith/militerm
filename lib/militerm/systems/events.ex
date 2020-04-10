defmodule Militerm.Systems.Events do
  @moduledoc """
  Manages sending events to entities.
  """

  alias Militerm.Systems.MML

  @doc """
  Shares the event with any other entity that can observe the triggering entity.
  """
  def trigger(entity_id, event, args) do
    # shares the event with anything that can observe the entity
    observers =
      case Militerm.Services.Location.where({:thing, entity_id}) do
        {prep, loc} -> [loc | Militerm.Services.Location.find_in(loc)]
        _ -> Militerm.Services.Location.find_in({:thing, entity_id})
      end

    args = Map.put(args, "trigger", entity_id)
    observed = {:thing, entity_id}
    args = Map.put(args, :trigger, observed)
    Militerm.Systems.Entity.event(observed, event, "observed", args)

    for observer <- observers -- [observed] do
      Militerm.Systems.Entity.event(observer, event, "observer", args)
    end

    :ok
  end

  def trigger(entity_id, event, role, args) do
    entity = {:thing, entity_id}
    args = Map.put(args, "trigger", entity)
    Militerm.Systems.Entity.event(entity, event, role, args)

    :ok
  end

  def async_trigger(entity_id, event, role, args) do
    entity = {:thing, entity_id}
    args = Map.put(args, "trigger", entity)
    Militerm.Services.Events.queue_event(entity_id, event, role, args)
    :ok
  end

  @doc """
  Shares narration with observers and participants.
  """
  def narrate(entity_id, message, slots, sense, ignore \\ []) do
    binding = MML.bind(message, slots)
    {prep, location} = Militerm.Services.Location.where(entity_id)
    observers = Militerm.Services.Location.find_in(location)
    used_slots = MML.used_slots(binding)

    used_slots = if "actor" in used_slots, do: used_slots, else: ["this" | used_slots]

    used_slots = if "actor" in used_slots, do: used_slots, else: ["this" | used_slots]

    # now go through each used slot and send the right message... and send to any observers
    # at the end who haven't seen the message yet
    do_narration(message, slots, used_slots, sense, 0, observers, ignore)
  end

  defp do_narration(_, _, _, [], _, _, ignore), do: ignore

  defp do_narration(loc, message, slots, [slot | other_slots], sense, distance, ignore) do
    targets = as_list(Map.get(slots, slot, [])) -- ignore

    for thing <- targets do
      Militerm.Systems.Entity.async_event(thing, "env:#{sense}", :observer, %{
        text: message
      })
    end

    do_narration(loc, message, slots, other_slots, sense, distance, targets ++ ignore)
  end

  defp as_list(nil), do: []
  defp as_list(list) when is_list(list), do: list
  defp as_list(thing), do: [thing]

  @doc """
  Runs the list of events given the objects listed for each slot. Each slot is considered the
  role.

  Actor is run first and must pass in the "pre-..." with `true` or `{:cont, pre, post}`.
  Each of the other slots is run and must pass with either `true` or `{:cont, pre, post}` or they are removed from the slot for further events.

  If any object in any slot returns `:halt` or `{:halt, message}`, then that is the last event
  that will be run, but everything will continue processing the events before the halt message.

  The halt message will be returned as a message that can be rendered for the actor.


  TODO: each event needs to be run pre-, main, post- before starting on pre- for the next one.
        as soon as an object returns a {:halt, ...}, then we finish running the event handlers
        for that event, but no more. (e.g., if pre- issues a :halt, we'll still do the main and post- but no more than for the event that issued the :halt)
  """
  def run_event_set([], _, _), do: :ok

  def run_event_set([event | events], slots, args) do
    pre_result = run_event_pre(event, slots, args)
    run_event_main(event, slots, args)
    run_event_post(event, slots, args)

    case pre_result do
      :halt ->
        :halt

      {:halt, message} ->
        {:halt, message}

      {:cont, []} ->
        run_event_set(events, slots, args)

      {:cont, new_events} ->
        run_event_set(new_events ++ events, slots, args)
    end
  end

  defp run_event_pre(event, [slot | slots], args) do
    result =
      Enum.reduce_while(to_list(Map.get(args, slot, [])), {:cont, [], false}, fn entity_id,
                                                                                 {:cont,
                                                                                  events_acc,
                                                                                  halted} = acc ->
        case Militerm.Systems.Entity.pre_event(entity_id, event, slot, args) do
          {:halt, message} ->
            {:halt, {:halt, message}}

          :halt ->
            {:cont, {:cont, events_acc, true}}

          {:cont, new_events} ->
            {:cont, {:cont, events_acc ++ new_events, halted}}

          _ ->
            {:cont, acc}
        end
      end)

    case result do
      {:halt, _} ->
        result

      {:cont, new_events, false} ->
        {:cont, new_events}

      {:cont, _, true} ->
        :halt
    end
  end

  defp run_event_main(event, slots, args) do
    for slot <- slots, entity_id <- to_list(Map.get(args, slot, [])) do
      Militerm.Systems.Entity.event(entity_id, event, slot, args)
    end
  end

  defp run_event_post(event, slots, args) do
    for slot <- slots, entity_id <- to_list(Map.get(args, slot, [])) do
      Militerm.Systems.Entity.post_event(entity_id, event, slot, args)
    end
  end

  defp to_list(list) when is_list(list), do: list
  defp to_list(scalar), do: [scalar]
end

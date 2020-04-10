defmodule Militerm.Systems.SimpleResponse do
  @moduledoc ~S"""
    The response system allows NPCs to map text string patterns to
    events. This is a fairly generic system, so the scripting needs to
    supply the string being matched as well as the set of matches. The
    returned event is then triggered by the script as well.

  response:
    set-name:
      - pattern: pattern
        events:
          - event1
          - event2

  The pattern is a regex with named captures available.

  This should be sufficient to build a bot based on the old Eliza game.
  """
  use Militerm.ECS.System

  defscript simple_response_trigger_event(set, text), for: objects do
    do_sr_trigger_event(objects, set, text)
  end

  defscript simple_response_trigger_event(set, text, default_event), for: objects do
    do_sr_trigger_event(objects, set, text, default_event)
  end

  def do_sr_trigger_event(%{"this" => this} = objects, set, [text], default_event \\ nil) do
    this
    |> get_pattern_set(set)
    |> find_match(text)
    |> trigger_event(objects, default_event)
  end

  def do_sr_trigger_event(_, _, _, _), do: false

  def get_pattern_set({:thing, thing_id}, set) do
    Militerm.Components.SimpleResponses.get_set(thing_id, set)
  end

  def get_pattern_set({:thing, thing_id, _}, set) do
    Militerm.Components.SimpleResponses.get_set(thing_id, set)
  end

  def find_match(patterns, text) do
    patterns
    |> Enum.find_value(fn %{"regex" => regex, "event" => event} ->
      case Regex.named_captures(regex, text) do
        %{} = captures -> {event, captures}
        _ -> false
      end
    end)
  end

  def trigger_event(nil, _, nil), do: false

  def trigger_event(nil, %{"this" => this} = objects, event) do
    do_trigger_event(this, event, objects)
    false
  end

  def trigger_event({event, captures}, %{"this" => this} = objects, _) do
    do_trigger_event(this, event, Map.merge(captures, objects))
  end

  def trigger_event(event, %{"this" => this} = objects, _) do
    do_trigger_event(this, event, objects)
    true
  end

  def do_trigger_event({:thing, thing_id}, event, args) do
    do_trigger_event(thing_id, event, args)
  end

  def do_trigger_event({:thing, thing_id, _}, event, args) do
    do_trigger_event(thing_id, event, args)
  end

  def do_trigger_event(thing_id, event, args) do
    Militerm.Systems.Events.async_trigger(thing_id, event, "responder", args)
    true
  end
end

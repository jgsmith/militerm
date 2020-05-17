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

  require Logger

  defscript simple_response_trigger_event(set, text), for: objects do
    do_sr_trigger_event(objects, set, text)
  end

  defscript simple_response_trigger_event(set, text, default_event), for: objects do
    do_sr_trigger_event(objects, set, text, default_event)
  end

  defscript random_selection(list) do
    if is_list(list) do
      count = Enum.count(list)
      Enum.at(list, :rand.uniform(count) - 1)
    else
      list
    end
  end

  def do_sr_trigger_event(objects, set, text, default_event \\ nil)

  def do_sr_trigger_event(objects, set, [text], default_event) do
    do_sr_trigger_event(objects, set, text, default_event)
  end

  def do_sr_trigger_event(%{"this" => this} = objects, set, text, default_event) do
    this
    |> get_pattern_set(set)
    |> log_pattern_set(this, set)
    |> find_match(text)
    |> log_match(this, set)
    |> trigger_event(objects, default_event)
  end

  def do_sr_trigger_event(_, _, _, _), do: false

  def get_pattern_set({:thing, thing_id}, set) do
    Militerm.Components.SimpleResponses.get_set(thing_id, set)
  end

  def get_pattern_set({:thing, thing_id, _}, set) do
    Militerm.Components.SimpleResponses.get_set(thing_id, set)
  end

  def log_pattern_set(patterns, {:thing, thing_id}, set) do
    Logger.debug(fn ->
      [thing_id, " SimpleResponseTriggerEvent ", set, " patterns: ", inspect(patterns)]
    end)

    patterns
  end

  def log_pattern_set(patterns, {:thing, thing_id, _}, set) do
    Logger.debug(fn ->
      [thing_id, " SimpleResponseTriggerEvent ", set, " patterns: ", inspect(patterns)]
    end)

    patterns
  end

  def find_match(patterns, text) do
    patterns
    |> Enum.find_value(fn %{"regex" => regex, "event" => event} ->
      case regex_matches(regex, text) do
        %{} = captures -> {event, captures}
        _ -> false
      end
    end)
  end

  def log_match(match, {:thing, thing_id, _}, set) do
    log_match(match, {:thing, thing_id}, set)
  end

  def log_match(match, {:thing, thing_id}, set) do
    Logger.debug(fn ->
      [thing_id, " SimpleResponseTriggerEvent ", set, " match: ", inspect(match)]
    end)

    match
  end

  def regex_matches([], _), do: false

  def regex_matches([regex | rest], text) do
    case Regex.named_captures(regex, text) do
      %{} = captures -> captures
      _ -> regex_matches(rest, text)
    end
  end

  def regex_matches(regex, text), do: Regex.named_captures(regex, text)

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

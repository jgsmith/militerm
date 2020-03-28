defmodule Militerm.Systems.Commands do
  @moduledoc """
  The Commands system parses user input in two categories: commands, starting with an
  at symbol (@), and narrative, not starting with an at symbol. Narrative commands
  start with a verb and take place within the game storyline. Commands take place outside
  of the game world.

  For example, consulting a map could be considered an in-game action if it is based on
  information or inventory of the character. If it's considered a free feature that everyone
  has regardless of in-game experience, then it might be an out-of-game command.

  On the other hand, managing a terminal's colors is an out-of-game (or out-of-character)
  action, and thus a command rather than a verb.
  """

  alias Militerm.Parsers.Command, as: Parser
  alias Militerm.Systems.Commands.Binder

  @obj_slots ~w[actor direct indirect instrument]

  def perform(entity_id, input, context) do
    do_perform(entity_id, normalize(input), context)
  end

  defp do_perform(entity_id, <<"@", input::binary>>, context) do
    with [command | rest] <- String.split(input, " ", parts: 2),
         {:ok, {module, function, args}} <- Militerm.Services.Commands.command_handler(command) do
      apply(module, function, [rest, %{"this" => entity_id}])
    else
      _ ->
        Militerm.Systems.Entity.receive_message(
          entity_id,
          "error:command",
          "{red}Unknown command: " <> input <> "{/red}"
        )
    end

    {:ok, context}
  end

  defp do_perform(entity_id, input, context) do
    with %{} = command <- Parser.parse(input, entity_id),
         %{slots: slots, syntax: %{actions: events}} <-
           Binder.bind(context, command) do
      # TODO: hoist the binding and filter out to the part going through the syntaxes
      #       if the needed slots aren't filled, then it's not a match
      slots =
        @obj_slots
        |> Enum.reduce(slots, fn slot, slots ->
          case Map.get(slots, slot) do
            nil ->
              slots

            [] ->
              slots

            v ->
              Map.put(
                slots,
                slot,
                v
                |> accepts_events(to_string(slot), events, slots)
                |> maybe_scalar
              )
          end
        end)

      slots =
        slots
        |> Enum.map(fn {k, v} -> {to_string(k), v} end)
        |> Enum.into(%{})

      all_slots_filled =
        map_size(slots) == 0 or
          Enum.all?(slots, fn
            {_, []} -> false
            {_, nil} -> false
            _ -> true
          end)

      actor_can =
        Enum.all?(events, fn event ->
          Militerm.Systems.Entity.can?(entity_id, event, "actor", slots)
        end)

      if all_slots_filled and actor_can do
        # now run event sequence
        result =
          Militerm.Systems.Events.run_event_set(
            events,
            @obj_slots,
            Map.put(slots, "actor", [entity_id])
          )

        case result do
          {:halt, message} ->
            Militerm.Systems.Entity.receive_message(
              entity_id,
              "error:command",
              "{red}{{message}}{/red}",
              %{"message" => message}
            )

          _ ->
            :ok
        end

        {:ok, context}
      else
        Militerm.Systems.Entity.receive_message(
          entity_id,
          "error:command",
          "{red}I can't {{input}}{/red}.",
          %{"input" => input}
        )

        {:unable, input}
      end
    else
      _ ->
        Militerm.Systems.Entity.receive_message(
          entity_id,
          "error:command",
          "{red}I don't know how to {{input}}{/red}.",
          %{"input" => input}
        )

        {:unknown, input}
    end
  end

  def accepts_events(list, slot, [event | _], slots) when is_list(list) do
    Enum.filter(list, fn entity_id ->
      Militerm.Systems.Entity.can?(entity_id, event, slot, slots)
    end)
  end

  def accepts_events(entity_id, slot, [event | _], slots) do
    if Militerm.Systems.Entity.can?(entity_id, event, slot, slots), do: entity_id, else: []
  end

  def maybe_scalar([v]), do: v
  def maybe_scalar(v), do: v

  defp normalize(string) do
    string
    |> String.trim()
    |> String.downcase()
    |> String.split(~r{\s+}, trim: true)
    |> Enum.join(" ")
  end
end

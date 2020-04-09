defmodule Militerm.Command.Plugs.RunEvents do
  @obj_slots ~w[actor direct indirect instrument]

  %{
    __struct__: Militerm.Command.Pipeline,
    context: %{
      actor: {:thing, "std:character#9259d0e8-c4ff-4313-a5e7-55f91b437a1c"}
    },
    entity: {:thing, "std:character#9259d0e8-c4ff-4313-a5e7-55f91b437a1c"},
    error: nil,
    input: "look",
    parse: %{
      adverbs: [],
      command: ["look"],
      slots: %{},
      syntax: %{actions: ["scan:env"], pattern: [], short: "", weight: 0}
    },
    parser: Militerm.Parsers.Command,
    phase: nil,
    state: :unhandled
  }

  def run(%{parse: %{syntax: %{actions: events}, slots: slots}, entity: entity}, _) do
    actor_can =
      Enum.all?(events, fn event ->
        Militerm.Systems.Entity.can?(entity, event, "actor", slots)
      end)

    if actor_can do
      result =
        Militerm.Systems.Events.run_event_set(
          events,
          @obj_slots,
          Map.put(slots, "actor", [entity])
        )

      case result do
        {:halt, message} ->
          {:error, message}

        _ ->
          :handled
      end
    else
      :cont
    end
  end

  def run(_, _), do: :cont
end

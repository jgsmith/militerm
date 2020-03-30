defmodule Militerm.Command.Plugs.RunEvents do
  @obj_slots ~w[actor direct indirect instrument]

  def run(%{parse: %{events: events, slots: slots}, entity: entity}, _) do
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

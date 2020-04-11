defmodule Militerm.Command.Plugs.RunEvents do
  @obj_slots ~w[actor direct indirect instrument]

  def run(%{parse: %{syntax: %{actions: events}, slots: slots}, entity: entity}, _) do
    actor_can =
      Enum.all?(events, fn event ->
        Militerm.Systems.Entity.can?(entity, event, "actor", slots)
      end)

    if actor_can do
      result =
        Militerm.Systems.Events.run_event_set(
          events ++ ["action:done"],
          @obj_slots,
          Map.put(slots, "actor", [entity])
        )

      entity_id =
        case entity do
          {:thing, id} -> id
          {:thing, id, _} -> id
        end

      # args = slots
      #   |> Map.put("actor", [entity])
      #   |> Map.put("this", entity)
      # IO.inspect({:async_trigger, entity_id, "action:done", "actor", args})
      # Militerm.Systems.Events.async_trigger(entity_id, "action:done", "actor", args)
      # 
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

defmodule Militerm.Command.Plugs.RunEvents do
  @obj_slots ~w[actor direct indirect instrument observer]

  def run(
        %{parse: %{syntax: %{actions: events} = syntax, slots: slots}, entity: entity} = state,
        _
      ) do
    actor_can =
      Enum.all?(events, fn event ->
        Militerm.Systems.Entity.can?(entity, event, "actor", slots)
      end)

    cond do
      actor_can ->
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

        case result do
          {:halt, message} ->
            {:error, message}

          _ ->
            :handled
        end

      !is_blank?(Map.get(syntax, :error)) ->
        {:cont, %{state | error: Map.get(syntax, :error)}}

      :else ->
        :cont
    end
  end

  def run(_, _), do: :cont

  defp is_blank?(nil), do: true
  defp is_blank?(""), do: true
  defp is_blank?(_), do: false
end

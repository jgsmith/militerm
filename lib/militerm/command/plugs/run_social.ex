defmodule Militerm.Command.Plugs.RunSocial do
  @obj_slots ~w[actor direct indirect instrument]

  def run(%{parse: %{slots: slots} = parse, entity: entity}, _) do
    observers =
      entity
      |> Militerm.Services.Location.find_near()
      |> Enum.map(fn item -> {item, "observer"} end)

    narrative = select_narrative(parse)

    if narrative do
      {:ok, bound_message} =
        narrative
        |> Militerm.Parsers.MML.parse!()
        |> Militerm.Systems.MML.bind(
          slots
          |> Map.put("actor", to_list(entity))
        )

      event = "msg:sight"

      entities =
        for slot <- ~w[actor direct indirect instrument],
            entities <- to_list(Map.get(slots, slot, [])),
            entity_id <- to_list(entities),
            do: {entity_id, slot}

      # TOOD: add observant entities in the environment
      entities = Enum.uniq_by(entities ++ observers, &elem(&1, 0))

      for {entity_id, role} <- entities do
        Militerm.Systems.Entity.event(entity_id, event, to_string(role), %{
          "this" => entity_id,
          "text" => bound_message,
          "intensity" => 0
        })
      end

      :handled
    else
      :cont
    end
  end

  def run(_, _), do: :cont

  defp select_narrative(%{slots: slots} = parse) do
    targeted = not is_empty?(Map.get(slots, "direct"))
    argument = not is_empty?(Map.get(slots, "string"))

    cond do
      targeted and argument ->
        parse
        |> Map.get(:syntax, %{})
        |> Map.get("target", %{})
        |> Map.get("argument", %{})
        |> Map.get("narrative")

      targeted ->
        parse
        |> Map.get(:syntax, %{})
        |> Map.get("target", %{})
        |> Map.get("no-argument", %{})
        |> Map.get("narrative")

      argument ->
        parse
        |> Map.get(:syntax, %{})
        |> Map.get("no-target", %{})
        |> Map.get("no-argument", %{})
        |> Map.get("narrative")

      :else ->
        parse
        |> Map.get(:syntax, %{})
        |> Map.get("no-target", %{})
        |> Map.get("no-argument", %{})
        |> Map.get("narrative")
    end
  end

  defp to_list(list) when is_list(list), do: list
  defp to_list(nil), do: []
  defp to_list(scalar), do: [scalar]

  defp is_empty?(nil), do: true
  defp is_empty?([]), do: true
  defp is_empty?([""]), do: true
  defp is_empty?(_), do: false
end

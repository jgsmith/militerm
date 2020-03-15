defmodule MilitermWeb.SceneView do
  use MilitermWeb, :view

  def component(%Ecto.Changeset{data: data, changes: changes}, component) do
    component = to_string(component)

    changed =
      changes
      |> Map.get(:source, [])
      |> Enum.find(fn changeset ->
        component in [Map.get(changeset.changes, :component), Map.get(changeset.data, :component)]
      end)

    unchanged =
      data
      |> Map.get(:source, [])
      |> Enum.find(fn
        %{component: ^component} -> true
        _ -> false
      end)

    cond do
      changed -> Map.get_lazy(changed.changes, :text, fn -> Map.get(changed.data, :text, "") end)
      unchanged -> unchanged.text
      :else -> ""
    end
  end

  def component(_, _), do: ""
end

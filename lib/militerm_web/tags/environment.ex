defmodule MilitermWeb.Tags.Environment do
  use Militerm.Systems.MML.Tags, device: :web

  deftag title(_attributes, children, bindings, pov) do
    content =
      case render_children(children, bindings, pov) do
        [binary | rest] when is_binary(binary) ->
          [String.capitalize(binary) | rest]

        [{:safe, binary} | rest] when is_binary(binary) ->
          [{:safe, String.capitalize(binary)} | rest]

        [{:safe, [binary | safe_rest]} | rest] when is_binary(binary) ->
          [{:safe, [String.capitalize(binary) | safe_rest]} | rest]

        otherwise ->
          otherwise
      end

    [{:safe, "<h1 class='font-bold underline'>"}, content, {:safe, "</h1>"}]
  end

  deftag env(attributes, children, bindings, pov) do
    content = render_children(children, bindings, pov)
    attributes = Keyword.get(attributes, :attributes, [])

    sense_attr =
      attributes
      |> Keyword.get(:attributes, [])
      |> Enum.find(fn {k, _} -> k == "sense" end)

    sense =
      case sense_attr do
        {_, [value]} -> value
        {_, value} -> value
        _ -> "sight"
      end

    case sense do
      "sound" -> [{:safe, "<span class='text-purple-600'>"}, content, {:safe, "</span>"}]
      "smell" -> [{:safe, "<span class='text-green-600'"}, content, {:safe, "</span>"}]
      _ -> content
    end
  end
end

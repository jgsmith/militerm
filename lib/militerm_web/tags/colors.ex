defmodule MilitermWeb.Tags.Colors do
  use Militerm.Systems.MML.Tags, device: :web

  deftag(black(_attributes, children, bindings, pov),
    do: color_span("text-black", children, bindings, pov)
  )

  deftag(red(_attributes, children, bindings, pov),
    do: color_span("text-red-600", children, bindings, pov)
  )

  deftag(green(_attributes, children, bindings, pov),
    do: color_span("text-green-600", children, bindings, pov)
  )

  deftag(yellow(_attributes, children, bindings, pov),
    do: color_span("text-yellow-500", children, bindings, pov)
  )

  deftag(blue(_attributes, children, bindings, pov),
    do: color_span("text-blue-600", children, bindings, pov)
  )

  deftag(magenta(_attributes, children, bindings, pov),
    do: color_span("text-red-800", children, bindings, pov)
  )

  deftag(cyan(_attributes, children, bindings, pov),
    do: color_span("text-teal-300", children, bindings, pov)
  )

  deftag(white(_attributes, children, bindings, pov),
    do: color_span("text-white", children, bindings, pov)
  )

  deftag(brown(_attributes, children, bindings, pov),
    do: color_span("text-yellow-800", children, bindings, pov)
  )

  deftag(dark_green(_attributes, children, bindings, pov),
    do: color_span("text-green-800", children, bindings, pov)
  )

  deftag(gray(_attributes, children, bindings, pov),
    do: color_span("text-gray-600", children, bindings, pov)
  )

  deftag(light_gray(_attributes, children, bindings, pov),
    do: color_span("text-gray-400", children, bindings, pov)
  )

  defp color_span(color, children, bindings, pov) do
    [
      {:safe, ["<span class='", color, "'>"]},
      render_children(children, bindings, pov),
      {:safe, "</span>"}
    ]
  end
end

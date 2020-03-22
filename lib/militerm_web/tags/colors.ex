defmodule MilitermWeb.Tags.Colors do
  use Militerm.Systems.MML.Tags, device: :web

  deftag(black(_attributes, children, bindings, pov),
    do: color_span("text-black", children, bindings, pov)
  )

  deftag(red(_attributes, children, bindings, pov),
    do: color_span("text-red", children, bindings, pov)
  )

  deftag(green(_attributes, children, bindings, pov),
    do: color_span("text-green", children, bindings, pov)
  )

  deftag(yellow(_attributes, children, bindings, pov),
    do: color_span("text-yellow", children, bindings, pov)
  )

  deftag(blue(_attributes, children, bindings, pov),
    do: color_span("text-blue", children, bindings, pov)
  )

  deftag(magenta(_attributes, children, bindings, pov),
    do: color_span("text-magenta", children, bindings, pov)
  )

  deftag(cyan(_attributes, children, bindings, pov),
    do: color_span("text-cyan", children, bindings, pov)
  )

  deftag(white(_attributes, children, bindings, pov),
    do: color_span("text-white", children, bindings, pov)
  )

  deftag(brown(_attributes, children, bindings, pov),
    do: color_span("text-brown", children, bindings, pov)
  )

  deftag(dark_green(_attributes, children, bindings, pov),
    do: color_span("text-dark-green", children, bindings, pov)
  )

  deftag(gray(_attributes, children, bindings, pov),
    do: color_span("text-gray", children, bindings, pov)
  )

  deftag(light_gray(_attributes, children, bindings, pov),
    do: color_span("text-light-gray", children, bindings, pov)
  )

  defp color_span(color, children, bindings, pov) do
    [
      {:safe, ["<span class='", color, "'>"]},
      render_children(children, bindings, pov),
      {:safe, "</span>"}
    ]
  end
end

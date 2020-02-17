# Militerm

A text-based MMORPG engine written in Elixir, Militerm builds on the pattern of LPC muds with a
core driver, mudlib, and content.

Militerm provides the driver and scripting support to develop the core content. Content can
be created through a web-based content creation system.

See (the example game)[https://github.com/jgsmith/militerm-example] for a demonstration.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `militerm` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:militerm, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/militerm](https://hexdocs.pm/militerm).

## Roadmap

The following features are in the works in no particular order.

- movement within scenes
- doors, gates, and guards to limit movement
- object binding
- soul commands

# Militerm

[![CircleCI](https://circleci.com/gh/jgsmith/militerm/tree/master.svg?style=svg)](https://circleci.com/gh/jgsmith/militerm/tree/master)

A text-based MMORPG engine written in Elixir, Militerm builds on the pattern of LPC muds with a
core driver, mudlib, and content.

Militerm provides the driver and scripting support to develop the core content. Content is managed through files, allowing the use of a revision control system of your choice.

See [an example game](https://github.com/jgsmith/exinfiltr8) for a demonstration.

## Development

To run a development server without having to install postgres locally:

```sh
docker-compose -f docker-compose.dev.yml up
```

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

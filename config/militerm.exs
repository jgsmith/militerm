# Militerm game configuration
use Mix.Config

alias Militerm.Components

config :militerm, :components,
  counter: Components.Counters,
  detail: Components.Details,
  eflag: Components.EphemeralFlag,
  egroup: Components.EphemeralGroup,
  epad: Components.EphemeralPad,
  flag: Components.Flags,
  identity: Components.Identity,
  location: Components.Location,
  resource: Components.Resources,
  skill: Components.Skills,
  stat: Components.Stats,
  "simple-response": Components.SimpleResponses,
  thing: Components.Things,
  trait: Components.Traits

config :militerm, :repo, Militerm.Repo

config :militerm, :game, character_archetype: "std:character"

config :gossip, :callback_modules,
  core: Militerm.Gossip,
  players: Militerm.Gossip,
  tells: Militerm.Gossip,
  games: Militerm.Gossip

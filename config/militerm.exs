# Militerm game configuration
use Mix.Config

alias Militerm.Components

config :militerm, :components,
  detail: Components.Details,
  eflag: Components.EphemeralFlag,
  epad: Components.EphemeralPad,
  flag: Components.Flags,
  identity: Components.Identity,
  location: Components.Location,
  thing: Components.Things,
  trait: Components.Traits

config :militerm, :repo, Militerm.Repo

config :gossip, :callback_modules,
  core: Militerm.Gossip,
  players: Militerm.Gossip,
  tells: Militerm.Gossip,
  games: Militerm.Gossip

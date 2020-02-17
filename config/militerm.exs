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
  trait: Components.Traits

config :militerm, :repo, Militerm.Repo

config :gossip, :callback_modules,
  core: Militerm.Callbacks.Core,
  players: Militerm.Callbacks.Players,
  tells: Militerm.Callbacks.Tells,
  games: Militerm.Callbacks.Games

# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :militerm,
  ecto_repos: [Militerm.Repo]

# Configures the endpoint
config :militerm, MilitermWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "QLq/13OQPLLM2dajw9qp5D/1LVQsJ0eeddK8dx2QWg7Kl2ZiSnT2eaIz7QxdqhI/",
  render_errors: [view: MilitermWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Militerm.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import militerm game configuration

import_config "militerm.exs"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
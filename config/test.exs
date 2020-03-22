use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :militerm, MilitermWeb.Endpoint,
  http: [port: 4002],
  server: false

config :militerm, :game, dir: "priv/test-game"

config :militerm,
  post_events_async: false

# Print only warnings and errors during test
config :logger, level: :warn

config :libcluster,
  topologies: []

# Configure your database
config :militerm, Militerm.Repo,
  username: "postgres",
  password: "postgres",
  database: "militerm_test",
  hostname: "postgres",
  pool: Ecto.Adapters.SQL.Sandbox

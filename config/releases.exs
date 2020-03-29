# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config
#
# config :militerm,
#   ecto_repos: [Militerm.Repo]

# Configures the endpoint
config :militerm, MilitermWeb.Endpoint,
  http: [port: System.fetch_env!("MILITERM_INTERNAL_HTTP_PORT")],
  url: [
    host: System.fetch_env!("MILITERM_HOST"),
    port: System.fetch_env!("MILITERM_EXTERNAL_HTTP_PORT")
  ],
  live_view: [
    signing_salt: System.fetch_env!("MILITERM_SECRET_KEY_BASE")
  ],
  cache_static_manifest: "priv/static/cache_manifest.json",
  secret_key_base: System.fetch_env!("MILITERM_SECRET_KEY_BASE"),
  pubsub: [name: Militerm.PubSub, adapter: Phoenix.PubSub.PG2],
  server: true

config :militerm, MilitermTelnet.Endpoint,
  tcp: [port: System.fetch_env!("MILITERM_INTERNAL_TELNET_PORT")],
  server: true

config :militerm, MilitermWeb.UserAuth.Guardian,
  issuer: "militerm",
  secret_key: System.fetch_env!("MILITERM_SECRET_KEY_BASE")

config :gossip, :client_id, System.fetch_env!("GRAPEVINE_CLIENT_ID")
config :gossip, :client_secret, System.fetch_env!("GRAPEVINE_CLIENT_SECRET")

config :militerm, :game, dir: System.fetch_env!("MILITERM_GAME_DIR")

config :militerm, :standalone, true

config :militerm, Militerm.Repo,
  username: System.fetch_env!("POSTGRES_USER"),
  password: System.fetch_env!("POSTGRES_PASSWORD"),
  database: System.fetch_env!("POSTGRES_DB"),
  hostname: System.fetch_env!("POSTGRES_HOST"),
  port: System.fetch_env!("POSTGRES_PORT"),
  pool_size: 15

cluster_topology =
  case System.fetch_env("LIBCLUSTER_STRATEGY") do
    {:ok, "k8s"} ->
      [
        default: [
          strategy: Cluster.Strategy.Kubernetes,
          config: [
            mode: :ip,
            kubernetes_node_basename: System.fetch_env!("NODE_BASENAME"),
            kubernetes_selector: System.fetch_env!("K8S_SELECTOR"),
            kubernetes_namespace: System.fetch_env!("K8S_NAMESPACE")
          ]
        ]
      ]

    {:ok, "rancher"} ->
      [
        default: [
          strategy: Cluster.Strategy.Rancher,
          config: [
            node_basename: System.fetch_env!("NODE_BASENAME")
          ]
        ]
      ]

    {:ok, "epmd"} ->
      [
        default: [
          strategy: Cluster.Strategy.Epmd,
          config: [
            hosts:
              Enum.map(
                String.split(System.fetch_env!("EPMD_HOSTS"), ~r{\s+}, trim: true),
                &String.to_atom/1
              )
          ]
        ]
      ]

    _ ->
      []
  end

config :libcluster,
  topologies: cluster_topology

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

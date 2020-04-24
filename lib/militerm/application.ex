defmodule Militerm.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    Militerm.Metrics.PlayerInstrumenter.setup()
    Militerm.Metrics.RepoInstrumenter.setup()
    Militerm.Metrics.PhoenixInstrumenter.setup()
    MilitermWeb.MetricsExporter.setup()

    :ok =
      :telemetry.attach(
        "prometheus-ecto",
        [:militerm, :repo, :query],
        &Militerm.Metrics.RepoInstrumenter.handle_event/4,
        %{}
      )

    master = Militerm.Config.master()

    # List all child processes to be supervised
    standalone = Application.get_env(:militerm, :standalone, false)

    services = master.services()

    interfaces =
      [
        MilitermTelnet.Endpoint
      ]
      |> Enum.filter(& &1.start_server?())

    caches =
      [
        {Militerm.Cache.Component, []},
        {Militerm.Cache.Session, []},
        {Militerm.Cache.Component.Primary, []},
        {Militerm.Cache.Session.Primary, []}
      ] ++ master.caches()

    endpoints = if standalone, do: [MilitermWeb.Endpoint], else: []

    repos = if standalone, do: [Militerm.Repo], else: []

    watchers = if Militerm.Config.watch_game_files(), do: [Militerm.Dev.GameWatcher], else: []

    cluster = [
      {Cluster.Supervisor,
       [
         Application.get_env(:libcluster, :topologies),
         [name: Militerm.ClusterSupervisor]
       ]}
    ]

    children = cluster ++ repos ++ caches ++ services ++ watchers ++ endpoints ++ interfaces

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Militerm.Supervisor]
    result = Supervisor.start_link(children, opts)

    Swarm.register_name(Gossip, Militerm.Gossip.Process, :start_link, [])

    for system <- master.systems(), do: system.initialize()
    for tag <- master.tags(), do: tag.initialize()

    result
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    MilitermWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

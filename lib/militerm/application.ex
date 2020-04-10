defmodule Militerm.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    standalone = Application.get_env(:militerm, :standalone, false)

    services = [
      # Starts a worker by calling: Militerm.Worker.start_link(arg)
      # {Militerm.Worker, arg},
      Militerm.Services.Commands,
      Militerm.Services.Events,
      Militerm.Services.GlobalMap,
      Militerm.Services.Verbs,
      Militerm.Services.Socials,
      Militerm.Services.Archetypes,
      Militerm.Services.Mixins,
      Militerm.Services.MML,
      Militerm.Services.Script
    ]

    interfaces =
      [
        MilitermTelnet.Endpoint
      ]
      |> Enum.filter(& &1.start_server?())

    caches = [
      {Militerm.Cache.LocalComponent, []},
      {Militerm.Cache.LocalSession, []},
      {Militerm.Cache.Component, []},
      {Militerm.Cache.Session, []}
    ]

    components = Map.values(Militerm.Config.components())

    endpoints = if standalone, do: [MilitermWeb.Endpoint], else: []

    repos = if standalone, do: [Militerm.Repo], else: []

    cluster = [
      {Cluster.Supervisor,
       [
         Application.get_env(:libcluster, :topologies),
         [name: Militerm.ClusterSupervisor]
       ]}
    ]

    children = cluster ++ repos ++ caches ++ services ++ components ++ endpoints ++ interfaces

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Militerm.Supervisor]
    result = Supervisor.start_link(children, opts)

    Swarm.register_name(Gossip, Militerm.Gossip.Process, :start_link, [])

    Task.async(&Militerm.Systems.Logger.initialize/0)
    Task.async(&Militerm.Systems.Entity.initialize/0)
    Task.async(&Militerm.Systems.Gossip.initialize/0)
    Task.async(&Militerm.Systems.MML.initialize/0)
    Task.async(&Militerm.Systems.Location.initialize/0)
    Task.async(&Militerm.Systems.SimpleResponse.initialize/0)
    Task.async(&MilitermWeb.Tags.Colors.initialize/0)
    Task.async(&MilitermWeb.Tags.Environment.initialize/0)
    Task.async(&Militerm.Tags.English.initialize/0)

    result
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    MilitermWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

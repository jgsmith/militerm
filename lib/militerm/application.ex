defmodule Militerm.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised

    services = [
      # Starts a worker by calling: Militerm.Worker.start_link(arg)
      # {Militerm.Worker, arg},
      Militerm.Services.Commands,
      Militerm.Services.GlobalMap,
      Militerm.Services.Verbs,
      Militerm.Services.Archetypes,
      Militerm.Services.Mixins,
      Militerm.Services.MML,
      Militerm.Services.Script
    ]

    components = Map.values(Militerm.Config.components())

    children = services ++ components

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Militerm.Supervisor]
    result = Supervisor.start_link(children, opts)

    Task.async(&Militerm.Systems.Logger.initialize/0)
    Task.async(&Militerm.Systems.Entity.initialize/0)
    Task.async(&Militerm.Systems.MML.initialize/0)
    Task.async(&Militerm.Systems.Location.initialize/0)
    Task.async(&MilitermWeb.Tags.Colors.initialize/0)
    Task.async(&MilitermWeb.Tags.Environment.initialize/0)
    Task.async(&Militerm.Tags.English.initialize/0)

    result
  end

  # # Tell Phoenix to update the endpoint configuration
  # # whenever the application is updated.
  # def config_change(changed, _new, removed) do
  #   MilitermWeb.Endpoint.config_change(changed, removed)
  #   :ok
  # end
end

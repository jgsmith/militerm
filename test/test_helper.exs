Supervisor.start_link([Militerm.Repo, MilitermWeb.Endpoint],
  strategy: :one_for_one,
  name: Militerm.TestSupervisor
)

ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Militerm.Repo, :manual)

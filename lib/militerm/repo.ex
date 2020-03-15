defmodule Militerm.Repo do
  use Ecto.Repo,
    otp_app: :militerm,
    adapter: Ecto.Adapters.Postgres
end

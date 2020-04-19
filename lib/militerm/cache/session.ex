defmodule Militerm.Cache.Session do
  use Nebulex.Cache,
    otp_app: :militerm,
    adapter: Nebulex.Adapters.Partitioned

  defmodule Primary do
    use Nebulex.Cache,
      otp_app: :militerm,
      adapter: Nebulex.Adapters.Local
  end
end

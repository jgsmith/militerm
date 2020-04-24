defmodule Militerm.Cache.Component do
  use Nebulex.Cache,
    otp_app: :militerm,
    adapter: Nebulex.Adapters.Partitioned

  defmodule Primary do
    use Nebulex.Cache,
      otp_app: :militerm,
      adapter: Nebulex.Adapters.Local
  end
end

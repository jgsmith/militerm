defmodule Militerm.Cache.Session do
  use Nebulex.Cache,
    otp_app: :militerm,
    adapter: Nebulex.Adapters.Dist
end

defmodule Militerm.Cache.Component do
  use Nebulex.Cache,
    otp_app: :militerm,
    adapter: Nebulex.Adapters.Dist
end

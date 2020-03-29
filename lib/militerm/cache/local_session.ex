defmodule Militerm.Cache.LocalSession do
  use Nebulex.Cache,
    otp_app: :militerm,
    adapter: Nebulex.Adapters.Local
end

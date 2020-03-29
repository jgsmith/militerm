defmodule Militerm.Cache.LocalComponent do
  use Nebulex.Cache,
    otp_app: :militerm,
    adapter: Nebulex.Adapters.Local
end

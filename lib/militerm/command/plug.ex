defmodule Militerm.Command.Plug do
  @moduledoc """
  The command plug specification.
  """

  @type opts ::
          binary
          | tuple
          | atom
          | integer
          | float
          | [opts]
          | %{optional(opts) => opts}
          | MapSet.t()

  @callback init(opts) :: opts
  @callback call(Plug.Conn.t(), opts) :: Plug.Conn.t()

  @callback init(opts) :: opts
  @callback call(Militerm.Command.Record.t(), opts) :: Plug.Militerm.Command.Record.t()
end

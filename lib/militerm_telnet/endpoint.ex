defmodule MilitermTelnet.Endpoint do
  @moduledoc """
  The controller listens for connections and manages them until they're ready to handle
  communication.
  """

  #
  # Based on the telnet support in ex_venture
  #

  require Logger

  def start_server?() do
    config = Application.get_env(:militerm, __MODULE__)
    config[:server]
  end

  def start_link() do
    config = Application.get_env(:militerm, __MODULE__)
    port = config_integer(config[:tcp][:port])

    opts = %{
      socket_opts: [{:port, port}],
      max_connections: 4096
    }

    case :ranch.start_listener(__MODULE__, :ranch_tcp, opts, MilitermTelnet.Protocol, []) do
      {:ok, _} = result ->
        Logger.info("Running #{__MODULE__} at 0.0.0.0:#{port} (telnet)")
        Logger.info("Access #{__MODULE__} at telnet://0.0.0.0:#{port}")
        result

      error ->
        error
    end
  end

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @doc """
  Sends the message to all children of the telnet endpoint. We need another way to make sure we
  can get this message across nodes in case the web process isn't on the same node as the telnet
  process.
  """
  def broadcast(message) do
    for pid <- :ranch.procs(__MODULE__, :connections) do
      GenServer.cast(pid, message)
    end
  end

  defp config_integer(string) when is_binary(string), do: String.to_integer(string)
  defp config_integer({:system, name}), do: config_integer(System.get_env(name))

  defp config_integer({:system, name, default}) do
    case System.get_env(name) do
      nil -> config_integer(default)
      "" -> config_integer(default)
      value -> config_integer(value)
    end
  end

  defp config_integer(number) when is_float(number), do: trunc(number)
  defp config_integer(number) when is_integer(number), do: number
end

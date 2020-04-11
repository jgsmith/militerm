defmodule MilitermTelnet.Protocol do
  use GenServer

  require Logger

  #
  # Based on the telnet support in ex_venture
  #

  @behaviour :ranch_protocol

  @iac 255
  @will 251
  @wont 252
  @telnet_do 253
  @telnet_dont 254
  @sb 250
  @se 240
  @nop 241
  @telnet_option_echo 1
  @ga 249
  @ayt 246

  @mssp 70
  @mccp 86
  @mxp 91
  @gmcp 201

  @cr 13
  @lf 10

  @crlf [@cr, @lf]

  @impl :ranch_protocol
  def start_link(ref, _socket, transport, opts) do
    pid = :proc_lib.spawn_link(__MODULE__, :init, [[ref, transport, opts]])
    {:ok, pid}
  end

  def authenticate_session(session_key, user_id) do
    Swarm.publish(:telnet, {:authenticate_session, session_key, user_id})
  end

  def receive_message(pid, "prompt", message) do
    GenServer.cast(pid, {:prompt, message})
  end

  def receive_message(pid, message_type, message) do
    GenServer.cast(pid, {:receive_message, message_type, message})
  end

  @doc """
  Renders the given MML and sends it to the telnet client.
  """
  def send_mml(%{entity_id: nil} = state, text) do
    binding = Militerm.Systems.MML.bind!(text, %{})
    send_data(state, Militerm.Systems.MML.render(binding, nil, :telnet))
  end

  def send_mml(%{entity_id: entity_id} = state, text) do
    binding = Militerm.Systems.MML.bind!(text, %{})
    send_data(state, Militerm.Systems.MML.render(binding, {:thing, entity_id}, :telnet))
  end

  @doc """
  Sends plain text without any MML rendering.
  """
  def send_text(state, text), do: send_data(state, [text, @crlf])

  def send_prompt(state, prompt), do: send_data(state, prompt)

  @impl true
  def init([ref, transport, _opts]) do
    # Logger.info("Player connecting", type: :socket)
    # PlayerInstrumenter.session_started(:telnet)

    {:ok, socket} = :ranch.handshake(ref)
    :ok = transport.setopts(socket, [{:active, true}])

    Process.flag(:trap_exit, true)

    Swarm.register_name(ref, self())

    GenServer.cast(self(), :start_session)

    :gen_server.enter_loop(__MODULE__, [], %{
      ref: ref,
      socket: socket,
      entity_id: nil,
      transport: transport,
      gmcp: false,
      gmcp_supports: [],
      mxp: false,
      character_id: nil,
      user_id: nil,
      restart_count: 0,
      mode: MilitermTelnet.Modes.Login,
      mode_state: nil,
      zlib_context: nil,
      config: %{}
    })
  end

  @impl true
  def handle_cast(:start_session, %{mode: mode} = state) do
    Swarm.join(:telnet, self())
    send_data(state, <<@iac, @will, @mccp>>)
    # send_data(state, <<@iac, @will, @mssp>>)
    # send_data(state, <<@iac, @will, @gmcp>>)
    # send_data(state, <<@iac, @will, @mxp>>)

    {:noreply, mode.start_session(state)}
  end

  def handle_cast(:disconnect, state) do
    handle_disconnect(state)
    {:stop, :normal, state}
  end

  def handle_cast({:receive_message, _message_type, message}, state) do
    send_data(state, [render_mml(state, message), @crlf])

    {:noreply, state}
  end

  def handle_cast({:prompt, prompt}, state) do
    # Sending IAC GA after the prompt helps clients like Mudlet

    send_data(state, [render_mml(state, prompt), @iac, @ga])
    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp, _port, data}, %{mode: mode} = state) do
    {text, new_state} = process_options(data, state)
    new_state = mode.process_input(new_state, text)

    if new_state.mode_state == :disconnect do
      handle_disconnect(new_state)
      {:stop, :normal, new_state}
    else
      {:noreply, new_state}
    end

    # {:noreply, mode.process_input(new_state, text)}
  end

  def handle_info({:tcp_closed, _port}, state) do
    handle_disconnect(state)
    {:stop, :normal, state}
  end

  def handle_info({:handshake, MilitermTelnet.Endpoint, :ranch_tcp, _port, _foo}, state) do
    {:ok, state}
  end

  @doc """
  This is used by the web controller to allow the connection to access the given character.
  """
  def handle_info({:authenticate_session, session_key, user_id}, %{mode: mode} = state) do
    if session_key == state.session_key && is_nil(state.user_id) do
      register_session_start(state)
      {:noreply, mode.authenticated(%{state | user_id: user_id})}
    else
      {:noreply, state}
    end
  end

  defp render_mml(%{entity_id: entity_id} = state, {:bound, _, _} = binding) do
    Militerm.Systems.MML.render(binding, {:thing, entity_id}, :telnet)
  end

  defp render_mml(_state, binary) when is_binary(binary) do
    binary
  end

  defp send_data(%{socket: socket, transport: transport} = state, data) do
    transport.send(socket, deflate(data, state))
  end

  defp deflate(data, %{zlib_context: nil}), do: data

  defp deflate(data, %{zlib_context: zlib_context}), do: :zlib.deflate(zlib_context, data, :full)

  def handle_disconnect(%{socket: socket, transport: transport} = state) do
    register_session_stop(state)

    case state do
      %{entity_id: entity_id} when not is_nil(entity_id) ->
        Militerm.Services.Characters.leave_game({:thing, entity_id})

      _ ->
        nil
    end

    disconnect(transport, socket, state)
  end

  defp disconnect(transport, socket, state) do
    terminate_zlib_context(state)

    transport.close(socket)
  end

  defp terminate_zlib_context(%{zlib_context: nil} = state), do: state

  defp terminate_zlib_context(%{zlib_context: zlib_context} = state) do
    :zlib.deflate(zlib_context, "", :finish)
    :zlib.deflateEnd(zlib_context)
    %{state | zlib_context: nil}
  end

  defp terminate_zlib_context(state), do: state

  def register_session_start(%{zlib_context: z, mxp: mxp} = state) do
    security = :none
    richness = if mxp, do: :mxp, else: :none
    compression = if z, do: :zlib, else: :none

    Militerm.Metrics.PlayerInstrumenter.start_session(:telnet, security, richness, compression)
  end

  def register_session_stop(%{zlib_context: z, mxp: mxp} = state) do
    security = :none
    richness = if mxp, do: :mxp, else: :none
    compression = if z, do: :mccp, else: :none

    Militerm.Metrics.PlayerInstrumenter.stop_session(:telnet, security, richness, compression)
  end

  def process_options(data, state, acc \\ [])

  def process_options(<<>>, state, acc) do
    {to_string(Enum.reverse(acc)), state}
  end

  def process_options(data, state, acc) do
    case data do
      <<@iac, @telnet_do, @mccp, data::binary>> ->
        Logger.info("Starting MCCP", type: :socket)
        zlib_context = :zlib.open()
        :zlib.deflateInit(zlib_context, 9)
        send_data(state, <<@iac, @sb, @mccp, @iac, @se>>)

        process_options(data, Map.put(state, :zlib_context, zlib_context), acc)

      <<@iac, @telnet_dont, @mccp, data::binary>> ->
        process_options(data, state, acc)

      # <<@iac, @telnet_do, @mssp, data::binary>> ->
      #   forward_options(socket, data)
      #   fun.(:mssp)

      <<@iac, @telnet_dont, @mssp, data::binary>> ->
        process_options(data, state, acc)

      <<@iac, @telnet_do, @gmcp, data::binary>> ->
        process_options(data, state, acc)

      <<@iac, @telnet_dont, @gmcp, data::binary>> ->
        process_options(data, state, acc)

      # <<@iac, @will, @gmcp, data::binary>> ->
      #   forward_options(socket, data)
      #   fun.({:gmcp, :will})

      <<@iac, @telnet_do, @mxp, data::binary>> ->
        Logger.info("Will do MXP", type: :socket)
        send_data(state, <<@iac, @sb, @mxp, @iac, @se>>)
        process_options(data, Map.put(state, :mxp, true), acc)

      <<@iac, @telnet_dont, @mxp, data::binary>> ->
        process_options(data, state, acc)

      # <<@iac, @sb, @gmcp, data::binary>> ->

      # {data, forward} = split_iac_sb(data)
      # forward_options(socket, forward)
      # fun.({:gmcp, data})

      <<@iac, @telnet_do, @telnet_option_echo, data::binary>> ->
        process_options(data, state, acc)

      <<@iac, @telnet_dont, @telnet_option_echo, data::binary>> ->
        process_options(data, state, acc)

      # <<@iac, @ayt, data::binary>> ->
      #   forward_options(socket, data)
      #   fun.(:ayt)

      <<@iac, @telnet_do, _, data::binary>> ->
        process_options(data, state, acc)

      <<@iac, @telnet_dont, _, data::binary>> ->
        process_options(data, state, acc)

      <<@iac, data::binary>> ->
        Logger.warn("Got weird iac data - #{inspect(data)}")
        process_options(data, state, acc)

      _ ->
        case String.split(data, <<@iac>>, parts: 2) do
          [text, rest] ->
            process_options(<<@iac, rest>>, state, [text | acc])

          [text] ->
            process_options(<<>>, state, [text | acc])
        end
    end
  end
end

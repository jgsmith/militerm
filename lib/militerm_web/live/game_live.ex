defmodule MilitermWeb.GameLive do
  use Phoenix.LiveView

  alias Militerm.Config

  def render(assigns) do
    ~L"""
    <div class="text-monospace h-100">
      <div class="row h-100">
        <div class="col-3 h-100">
          <div class="">
            <h2>Map</h2>
            <%= @location.prep %> <%= @location.target %> @ <%= @location.coord %>
          </div>
          <div class=""><h2><%= @character.name %></h2></div>
        </div>
        <div class="col-9 h-100">
          <div class="narrative-panel">
            <div id="narration" class="container" phx-update="append"  phx-hook="ScrollToEnd">
              <%= for {message, idx} <- Enum.with_index(Enum.reverse(@messages)) do %>
                <div class="bg-gray-900 text-gray-100 font-mono" id="<%= @message_counter %>-<%= idx %>"><%= message %></div>
              <% end %>
            </div>
            <div id="narration-end"></div>
          </div>
          <div class="prompt">
            <form phx-submit="command" class="">
              <input class="inline-block" type="text" name="command" />
            </form>
          </div>
        </div>
        <!-- div class="col-2 h-100">
          <div class=""><h2>Comms</h2></div>
        </div -->
      </div>
    </div>
    """
  end

  def receive_message(pid, "prompt", message) do
    # we don't display a prompt in the web client
    :ok
  end

  def receive_message(pid, message_type, message) do
    GenServer.cast(pid, {:receive_message, message_type, message})
  end

  ###
  ###
  ###

  def mount(_, %{"character" => character, "current_user" => user_id}, socket) do
    %{entity_id: entity_id} = Militerm.Accounts.get_character!(user_id: user_id, name: character)

    Militerm.Services.Characters.enter_game({:thing, entity_id}, receiver: __MODULE__)

    Militerm.Metrics.PlayerInstrumenter.start_session(:web, :https, :html, :default)

    ident = Militerm.Components.Identity.get(entity_id)

    character = %{name: ident["name"]}

    {prep, {:thing, target_id, t}} = Militerm.Services.Location.where({:thing, entity_id})

    {:ok,
     assign(socket,
       location: %{prep: prep, target: target_id, coord: t},
       character: character,
       entity_id: entity_id,
       prompt: "> ",
       messages: [],
       message_counter: 1,
       user_id: user_id
     ), temporary_assigns: [messages: []]}
  end

  def terminate(reason, socket) do
    # unload character
    Militerm.Metrics.PlayerInstrumenter.stop_session(:web, :https, :html, :default)
    Militerm.Services.Characters.leave_game({:thing, socket.assigns.entity_id})
    :ok
  end

  def handle_event("command", %{"command" => command}, socket) do
    # send command through parser / event system
    Militerm.Systems.Entity.process_input_async({:thing, socket.assigns.entity_id}, command)

    {:noreply,
     assign(socket,
       message_counter: socket.assigns.message_counter + 1,
       messages: [[socket.assigns.prompt, " ", command]]
     )}
  end

  def handle_cast({:receive_message, message_type, message}, socket) do
    {prep, {:thing, target_id, t}} =
      Militerm.Services.Location.where({:thing, socket.assigns.entity_id})

    # parse message and render it as MML

    {:noreply,
     assign(socket,
       location: %{prep: prep, target: target_id, coord: t},
       message_counter: socket.assigns.message_counter + 1,
       messages: [render_mml(socket.assigns.entity_id, message)]
     )}
  end

  defp render_mml(entity_id, text) when is_binary(text) do
    case Militerm.Systems.MML.bind(text, %{"this" => {:thing, entity_id}}) do
      {:ok, binding} ->
        render_mml(entity_id, binding)

      _ ->
        text
    end
  end

  defp render_mml(entity_id, {:bound, _, _} = binding) do
    Militerm.Systems.MML.render(binding, {:thing, entity_id}, :web)
  end
end

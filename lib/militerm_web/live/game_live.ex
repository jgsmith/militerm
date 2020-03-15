defmodule MilitermWeb.GameLive do
  use Phoenix.LiveView

  alias Militerm.Config

  def render(assigns) do
    ~L"""
    <div class="h-full font-mono">
      <div class="flex flex-row m-1">
        <div class="flex flex-col flex-none w-1/4 p-2">
          <div class="border border-solid border-white">
            <h1>Map</h1>
            <%= @location.prep %> <%= @location.target %>@<%= @location.coord %>
          </div>
          <div class="border border-solid border-white p-2"><h1><%= @character.name %></h1></div>
        </div>
        <div class="flex flex-col flex-grow w-1/2 m-1">
          <div class="narrative-panel">
            <div id="narration" class="container" phx-update="append"  phx-hook="ScrollToEnd">
              <%= for {message, idx} <- Enum.with_index(Enum.reverse(@messages)) do %>
                <div class="bg-gray-900 text-gray-100 font-mono" id="<%= @message_counter %>-<%= idx %>"><%= message %></div>
              <% end %>
            </div>
            <div id="narration-end"></div>
          </div>
          <div class="prompt w-full">
            <form phx-submit="command" class="">
              <input class="inline-block w-full bg-gray-900 text-gray-100 border border-solid border-black focus:bg-gray-900" type="text" name="command" />
            </form>
          </div>
        </div>
        <div class="flex flex-col flex-none w-1/4 m-1">
          <div class="border border-solid border-white m-1 p-1"><h1>Communication</h1></div>
        </div>
      </div>
    </div>
    """
  end

  def receive_message(pid, message_type, message) do
    GenServer.cast(pid, {:receive_message, message_type, message})
  end

  ###
  ###
  ###

  def mount(_session, socket) do
    {:ok, assign(socket, messages: [], message_counter: 1, prompt: "[...]", user_id: 1)}
  end

  def terminate(reason, socket) do
    # IO.inspect({:terminate, reason})
    # unload character
    Militerm.Services.Characters.leave_game({:thing, socket.assigns.entity_id})
    :ok
  end

  def handle_params(%{"character" => character} = params, _uri, socket) do
    # this is where we handle connecting to the right character? logging in is done elsewhere
    # for now, assume that the user is authenticated and that the character name is in the params

    %{entity_id: entity_id} =
      Militerm.Accounts.get_character!(user_id: socket.assigns.user_id, name: character)

    Militerm.Services.Characters.enter_game({:thing, entity_id}, receiver: __MODULE__)

    ident = Militerm.Components.Identity.get(entity_id)

    character = %{name: ident["name"]}

    {prep, {:thing, target_id, t}} = Militerm.Services.Location.where({:thing, entity_id})

    {:noreply,
     assign(socket,
       location: %{prep: prep, target: target_id, coord: t},
       character: character,
       entity_id: entity_id
     )}
  end

  def handle_event("command", %{"command" => command}, socket) do
    # send command through parser / event system
    Militerm.Systems.Entity.process_input({:thing, socket.assigns.entity_id}, command)

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

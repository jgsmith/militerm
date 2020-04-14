defmodule Militerm.Systems.Entity.Controller do
  use GenServer

  alias Militerm.Config
  alias Militerm.Systems.MML

  alias Militerm.Systems.Entity

  @moduledoc """
  Manages control of an entity -- managing events more than anything else.
  """

  def start_link(entity_id, entity_module) do
    GenServer.start_link(__MODULE__, [entity_id, entity_module])
  end

  def child_spec(opts \\ []) do
    entity_id = Keyword.fetch!(opts, :entity_id)
    entity_module = Keyword.fetch!(opts, :entity_module)

    %{
      id: {:via, :swarm, entity_id},
      start: {__MODULE__, :start_link, [entity_id, entity_module]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  ###
  ### Public API
  ###

  def set_property({:thing, entity_id, coord}, ["detail", "default" | path], value, args)
      when is_binary(coord) do
    set_property(
      {:thing, entity_id},
      ["detail", coord | path],
      value,
      Map.put(args, "coord", coord)
    )
  end

  def set_property({:thing, entity_id, coord}, path, value, args) do
    set_property({:thing, entity_id}, path, value, Map.put(args, "coord", coord))
  end

  def set_property({:thing, entity_id} = thing, [component | path] = full_path, value, args) do
    bin_path = full_path |> Enum.reverse() |> Enum.join(":")

    validated_value =
      if validates?(thing, bin_path) do
        validate(thing, bin_path, value, args)
      else
        value
      end

    old_value = property(thing, full_path, args)

    if is_nil(validated_value) do
      old_value
    else
      component_atom = String.to_existing_atom(component)

      case Map.fetch(Militerm.Config.master().components(), component_atom) do
        {:ok, module} ->
          module.set_value(entity_id, path, validated_value)

          if old_value != validated_value do
            # trigger change event
            event = "change:#{Enum.join(full_path, ":")}"

            Militerm.Systems.Events.trigger(entity_id, event, %{
              "observed" => [thing],
              "prior" => old_value,
              "value" => validated_value
            })
          end

        _ ->
          nil
      end
    end
  end

  def set_property(_, _, _, _), do: nil

  def reset_property({:thing, entity_id, coord}, ["detail", "default" | path], args)
      when is_binary(coord) do
    reset_property({:thing, entity_id}, ["detail", coord | path], Map.put(args, "coord", coord))
  end

  def reset_property({:thing, entity_id, coord}, path, args) do
    reset_property({:thing, entity_id}, path, Map.put(args, "coord", coord))
  end

  def reset_property({:thing, entity_id}, [component | path], args) do
    component_atom = String.to_existing_atom(component)

    case Map.fetch(Militerm.Config.master().components(), component_atom) do
      {:ok, module} ->
        module.reset_value(entity_id, path)

      _ ->
        nil
    end
  end

  def reset_property(_, _, _), do: nil

  def remove_property({:thing, entity_id, coord}, ["detail", "default" | path])
      when is_binary(coord) do
    remove_property({:thing, entity_id}, ["detail", coord | path])
  end

  def remove_property({:thing, entity_id, coord}, path) do
    remove_property({:thing, entity_id}, path)
  end

  def remove_property({:thing, entity_id}, [component | path]) do
    component_atom = String.to_existing_atom(component)

    case Map.fetch(Militerm.Config.master().components(), component_atom) do
      {:ok, module} ->
        module.remove_value(entity_id, path)

      _ ->
        nil
    end
  end

  def property({:thing, entity_id, coord}, ["raw", "detail", "default" | path], args)
      when is_binary(coord) do
    property(
      {:thing, entity_id},
      ["raw", "detail", coord | path],
      Map.put(args, "coord", coord)
    )
  end

  def property({:thing, entity_id, coord}, ["detail", "default" | path], args)
      when is_binary(coord) do
    property({:thing, entity_id}, ["detail", coord | path], Map.put(args, "coord", coord))
  end

  def property({:thing, entity_id, coord}, path, args) do
    property({:thing, entity_id}, path, Map.put(args, "coord", coord))
  end

  def property(this, ["raw" | path], args), do: raw_property(this, path, args)

  def property({:thing, entity_id} = this, [component | path] = full_path, args) do
    # we're just reading, so no need to forward to the GenServer
    bin_path = full_path |> Enum.join(":")

    if calculates?(this, bin_path) do
      calculate(this, bin_path, args)
    else
      raw_property(this, full_path, args)
    end
  end

  def property(_, _, _), do: nil

  def raw_property({:thing, entity_id}, [component | path], _args) do
    component_atom = String.to_existing_atom(component)

    case Map.fetch(Militerm.Config.master().components(), component_atom) do
      {:ok, module} ->
        module.get_value(entity_id, path)

      _ ->
        nil
    end
  end

  def calculates?({:thing, entity_id}, path) do
    case Militerm.Components.Entity.module(entity_id) do
      {:ok, module} ->
        apply(module, :calculates?, [entity_id, path])

      _ ->
        false
    end
  end

  def calculate({:thing, entity_id}, path, args) do
    case Militerm.Components.Entity.module(entity_id) do
      {:ok, module} ->
        apply(module, :calculate, [entity_id, path, args])

      _ ->
        nil
    end
  end

  def pre_event({:thing, entity_id, coord}, event, role, args) do
    pre_event({:thing, entity_id}, event, role, Map.put(args, "coord", coord))
  end

  def pre_event({:thing, entity_id} = entity, event, role, args) do
    case Entity.whereis(entity) do
      {:ok, pid} ->
        if pid == self() do
          case Militerm.Components.Entity.module(entity_id) do
            {:ok, module} ->
              apply(module, :handle_event, [entity_id, "pre-" <> event, role, args])

            _ ->
              false
          end
        else
          GenServer.call(pid, {:pre_event, event, role, args})
        end

      _ ->
        false
    end
  end

  def pre_event(_, _, _, _), do: false

  def event({:thing, entity_id, coord}, event, role, args) do
    event({:thing, entity_id}, event, role, Map.put(args, "coord", coord))
  end

  def event({:thing, entity_id} = entity, event, role, args) do
    case Entity.whereis(entity) do
      {:ok, pid} ->
        if pid == self() do
          case Militerm.Components.Entity.module(entity_id) do
            {:ok, module} ->
              apply(module, :handle_event, [entity_id, event, role, args])

            _ ->
              nil
          end
        else
          GenServer.call(pid, {:event, event, role, args})
        end

      _ ->
        nil
    end
  end

  def event(_, _, _, _), do: nil

  @doc """
  Returns a task that can be joined, if needed.
  """
  def async_event({:thing, entity_id, coord}, event, role, args) do
    async_event({:thing, entity_id}, event, role, Map.put(args, "coord", coord))
  end

  def async_event({:thing, entity_id} = entity, event, role, args) do
    case Entity.whereis(entity) do
      {:ok, pid} ->
        if pid == self() do
          case Militerm.Components.Entity.module(entity_id) do
            {:ok, module} ->
              Task.start(module, :handle_event, [entity_id, event, role, args])

            _ ->
              Task.start(fn -> nil end)
          end
        else
          Task.start(fn ->
            GenServer.call(pid, {:event, event, role, args})
          end)
        end

      _ ->
        nil
    end
  end

  def async_event(_, _, _, _), do: nil

  def post_event({:thing, entity_id, coord}, event, role, args) do
    post_event({:thing, entity_id}, event, role, Map.put(args, "coord", coord))
  end

  def post_event({:thing, entity_id} = entity, event, role, args) do
    case Entity.whereis(entity) do
      {:ok, pid} ->
        if pid == self() do
          case Militerm.Components.Entity.module(entity_id) do
            {:ok, module} ->
              apply(module, :handle_event, [entity_id, "post-" <> event, role, args])

            _ ->
              nil
          end
        else
          GenServer.call(pid, {:post_event, event, role, args})
        end

      _ ->
        nil
    end
  end

  def post_event(_, _, _, _), do: nil

  def can?({:thing, entity_id, coord}, ability, role, args) do
    can?({:thing, entity_id}, ability, role, Map.put(args, "coord", coord))
  end

  def can?({:thing, entity_id} = entity, ability, role, args) do
    case Entity.whereis(entity) do
      {:ok, pid} ->
        if pid == self() do
          case Militerm.Components.Entity.module(entity_id) do
            {:ok, module} ->
              apply(module, :can?, [entity_id, ability, role, args])

            _ ->
              false
          end
        else
          GenServer.call(pid, {:can, ability, role, args})
        end

      _ ->
        false
    end
  end

  def can?(_, _, _, _), do: false

  def is?(thing, trait, args \\ %{})

  def is?({:thing, entity_id, coord}, trait, args) do
    is?({:thing, entity_id}, trait, Map.put(args, "coord", coord))
  end

  def is?({:thing, entity_id} = entity, trait, args) do
    case Entity.whereis(entity) do
      {:ok, pid} ->
        if pid == self() do
          case Militerm.Components.Entity.module(entity_id) do
            {:ok, module} ->
              apply(module, :is?, [entity_id, trait, args])

            _ ->
              false
          end
        else
          GenServer.call(pid, {:is, trait, args})
        end

      _ ->
        false
    end
  end

  def is?(_, _, _), do: false

  def validates?({:thing, entity_id} = entity, path) do
    case Entity.whereis(entity) do
      {:ok, pid} ->
        if pid == self() do
          case Militerm.Components.Entity.module(entity_id) do
            {:ok, module} ->
              apply(module, :validates?, [entity_id, path])

            _ ->
              false
          end
        else
          GenServer.call(pid, {:validates?, path})
        end

      _ ->
        false
    end
  end

  def validate({:thing, entity_id} = entity, path, value, args) do
    case Entity.whereis(entity) do
      {:ok, pid} ->
        if pid == self() do
          case Militerm.Components.Entity.module(entity_id) do
            {:ok, module} ->
              apply(module, :validate, [entity_id, path, value, args])

            _ ->
              false
          end
        else
          GenServer.call(pid, {:validate, path, value, args})
        end

      _ ->
        false
    end
  end

  ###
  ### Implementation
  ###

  @impl true
  def init([entity_id, entity_module]) do
    {:ok,
     %{
       module: entity_module,
       entity_id: entity_id,
       context: %{actor: {:thing, entity_id}},
       interfaces: []
     }}
  end

  @impl true
  def handle_info({:swarm, :die}, state) do
    {:stop, :shutdown, state}
  end

  def handle_info(
        {:gossip_player_sign_in, game, player},
        %{module: module, entity_id: entity_id} = state
      ) do
    apply(module, :handle_event, [
      entity_id,
      "gossip:player:sign_in",
      "player",
      %{"game" => game, "player" => player}
    ])

    {:noreply, state}
  end

  def handle_info(
        {:gossip_player_sign_out, game, player},
        %{module: module, entity_id: entity_id} = state
      ) do
    apply(module, :handle_event, [
      entity_id,
      "gossip:player:sign_out",
      "player",
      %{"game" => game, "player" => player}
    ])

    {:noreply, state}
  end

  def handle_info(
        {:gossip_player_sign_in, player},
        %{module: module, entity_id: entity_id} = state
      ) do
    apply(module, :handle_event, [
      entity_id,
      "local:player:sign_in",
      "player",
      %{"player" => player}
    ])

    {:noreply, state}
  end

  def handle_info(
        {:gossip_player_sign_out, player},
        %{module: module, entity_id: entity_id} = state
      ) do
    apply(module, :handle_event, [
      entity_id,
      "local:player:sign_out",
      "player",
      %{"player" => player}
    ])

    {:noreply, state}
  end

  def handle_info(
        {:gossip_channel_broadcast, game, player, channel, message},
        %{module: module, entity_id: entity_id} = state
      ) do
    apply(module, :handle_event, [
      entity_id,
      "gossip:channel:broadcast",
      "player",
      %{"game" => game, "player" => player, "channel" => channel, "message" => message}
    ])

    {:noreply, state}
  end

  def handle_info({:gossip_game_up, game}, %{module: module, entity_id: entity_id} = state) do
    apply(module, :handle_event, [entity_id, "gossip:game:up", "player", %{"game" => game}])
    {:noreply, state}
  end

  def handle_info({:gossip_game_down, game}, %{module: module, entity_id: entity_id} = state) do
    apply(module, :handle_event, [entity_id, "gossip:game:down", "player", %{"game" => game}])
    {:noreply, state}
  end

  @impl true
  def handle_cast({:swarm, :end_handoff, state}, _state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:swarm, :resolve_conflict, state}, _state) do
    {:noreply, state}
  end

  # @impl true
  # def handle_cast(
  #       {:post_event, event, role, args},
  #       %{module: module, entity_id: entity_id} = state
  #     ) do
  #   apply(module, :handle_event, [entity_id, "post-" <> event, role, args])
  #   {:noreply, state}
  # end

  @impl true
  def handle_cast(
        {:process_input, input},
        %{context: context, module: module, entity_id: entity_id} = state
      ) do
    new_context = apply(module, :process_input, [entity_id, input, context])

    {:noreply, %{state | context: new_context}}
  end

  @impl true
  def handle_call(
        {:process_input, input},
        _from,
        %{context: context, module: module, entity_id: entity_id} = state
      ) do
    new_context = apply(module, :process_input, [entity_id, input, context])

    {:reply, :ok, %{state | context: new_context}}
  end

  def handle_call(:get_entity_id, _from, %{entity_id: entity_id} = state) do
    {:reply, entity_id, state}
  end

  @impl true
  def handle_call(
        {:post_event, event, role, args},
        _from,
        %{module: module, entity_id: entity_id} = state
      ) do
    {:reply, apply(module, :handle_event, [entity_id, "post-" <> event, role, args]), state}
  end

  @impl true
  def handle_call(
        {:register_interface, module},
        {pid, _} = _from,
        %{interfaces: interfaces} = state
      ) do
    pair = {pid, module}

    if pair in interfaces do
      {:reply, :ok, state}
    else
      {:reply, :ok, %{state | interfaces: [{pid, module} | interfaces]}}
    end
  end

  @impl true
  def handle_call(:unregister_interface, {pid, _} = _from, %{interfaces: interfaces} = state) do
    remaining_interfaces =
      interfaces
      |> Enum.reject(fn
        {^pid, _} -> true
        _ -> false
      end)

    {:reply, :ok, %{state | interfaces: remaining_interfaces}}
  end

  @impl true
  def handle_call(:registered_interfaces, _from, %{interfaces: interfaces} = state) do
    {:reply, interfaces, state}
  end

  @impl true
  def handle_call(
        {:receive_message, message_type, message},
        _from,
        %{interfaces: interfaces} = state
      ) do
    for {pid, module} <- interfaces do
      apply(module, :receive_message, [pid, message_type, message])
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:swarm, :begin_handoff}, _from, state) do
    {:reply, {:resume, state}, state}
  end

  def handle_call(:shutdown, state) do
    {:stop, :shutdown, state}
  end

  def handle_call(
        {:pre_event, event, role, args},
        _from,
        %{module: module, entity_id: entity_id} = state
      ) do
    {:reply, apply(module, :handle_event, [entity_id, "pre-" <> event, role, args]), state}
  end

  def handle_call(
        {:event, event, role, args},
        _from,
        %{module: module, entity_id: entity_id} = state
      ) do
    {:reply, apply(module, :handle_event, [entity_id, event, role, args]), state}
  end

  def handle_call(
        {:can, ability, role, args},
        _from,
        %{module: module, entity_id: entity_id} = state
      ) do
    {:reply, apply(module, :can?, [entity_id, ability, role, args]), state}
  end

  def handle_call(
        {:is, trait, args},
        _from,
        %{module: module, entity_id: entity_id} = state
      ) do
    {:reply, apply(module, :is?, [entity_id, trait, args]), state}
  end

  def handle_call(
        {:validates?, path},
        _from,
        %{module: module, entity_id: entity_id} = state
      ) do
    {:reply, apply(module, :validates?, [entity_id, path]), state}
  end

  def handle_call(
        {:validate, path, value, args},
        _from,
        %{module: module, entity_id: entity_id} = state
      ) do
    {:reply, apply(module, :validate, [entity_id, path, value, args]), state}
  end
end

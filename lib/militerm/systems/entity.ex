defmodule Militerm.Systems.Entity do
  use Militerm.ECS.System

  alias Militerm.Config
  alias Militerm.Components
  alias Militerm.Systems.MML
  alias Militerm.Systems.Entity.Controller

  require Logger

  @moduledoc """
  Manages control of an entity -- managing events more than anything else.
  """

  defscript id(), for: %{"this" => this} do
    case this do
      {:thing, entity_id} -> entity_id
      {:thing, entity_id, _} -> entity_id
      _ -> nil
    end
  end

  defscript id(thing) do
    case thing do
      {:thing, entity_id} -> entity_id
      {:thing, entity_id, _} -> entity_id
      _ -> nil
    end
  end

  defdelegate set_property(entity_id, path, value, args), to: Controller
  defdelegate reset_property(entity_id, path, args), to: Controller
  defdelegate remove_property(entity_id, path), to: Controller
  defdelegate property(entity_id, path, args), to: Controller
  defdelegate calculates?(entity_id, path), to: Controller
  defdelegate calculate(entity_id, path, args), to: Controller
  defdelegate validates?(entity_id, path), to: Controller
  defdelegate validate(entity_id, path, value, args), to: Controller
  defdelegate pre_event(entity_id, event, role, args), to: Controller
  defdelegate event(entity_id, event, role, args), to: Controller
  defdelegate async_event(entity_id, event, role, args), to: Controller
  defdelegate post_event(entity_id, event, role, args), to: Controller
  defdelegate can?(entity_id, ability, role, args), to: Controller
  defdelegate is?(entity_id, trait, args \\ %{}), to: Controller

  defscript create(archetype), for: %{"this" => this} = _objects do
    do_create(this, archetype)
  end

  defscript create(archetype, data), for: %{"this" => this} = _objects do
    do_create(this, archetype, data)
  end

  def create(archetype, location, data \\ %{}) do
    entity_id = "#{archetype}##{UUID.uuid4()}"
    entity = {:thing, entity_id}

    Militerm.Entities.Thing.create(entity_id, archetype, data)
    Militerm.Systems.Location.place(entity, location)
    Militerm.Systems.Events.trigger(entity_id, "object:created", %{"this" => entity})
    entity
  end

  def do_create(target, archetype, data \\ %{}) do
    entity_id = "#{archetype}##{UUID.uuid4()}"
    entity = {:thing, entity_id}

    Militerm.Entities.Thing.create(entity_id, archetype, data)
    Militerm.Systems.Location.place(entity, {"in", target})
    Militerm.Systems.Events.trigger(entity_id, "object:created", %{"this" => entity})
    entity
  end

  defscript destroy(), for: %{"this" => {:thing, entity_id} = entity} = _objects do
    # actually destroy the entity
    Militerm.Systems.Location.remove_entity(entity)
    Militerm.ECS.Entity.delete_entity(entity_id)
  end

  defscript destroy({:thing, entity_id} = entity) do
    Militerm.Systems.Events.trigger(entity_id, "object:destroy", %{"this" => entity})
  end

  defcommand update(thing), for: %{"this" => {:thing, this_id} = this} = args do
    if Enum.any?(["admin", "builders"], &Components.EphemeralGroup.get_value(this_id, [&1])) do
      entity_id =
        case thing do
          # update this location
          "" ->
            case Militerm.Services.Location.where(this) do
              {_, {:thing, id, _}} -> id
              _ -> nil
            end

          "here" ->
            case Militerm.Services.Location.where(this) do
              {_, {:thing, id, _}} -> id
              _ -> nil
            end

          "me" ->
            this_id

          # might be an entity_id
          bit ->
            case whereis(bit) do
              {:ok, _} ->
                bit

              # it's a thing - let's find it!
              _ ->
                case Militerm.Systems.Commands.Binder.bind_slot(
                       :direct,
                       {:object, :singular, [:here], bit},
                       {%{}, %{}}
                     ) do
                  {_, %{direct: [{:thing, id} | _]}} -> id
                  {_, %{direct: [{:thing, id, _} | _]}} -> id
                  _ -> nil
                end
            end
        end

      if entity_id do
        # update entity_id - means redoing the data
        # doesn't erase anything -- just replaces any data with the settings
        # from the archetype
        data =
          case Militerm.Components.Entity.archetype(entity_id) do
            {:ok, archetype} ->
              case Militerm.Services.Archetypes.get(archetype) do
                %{data: data} -> data
                _ -> %{}
              end

            _ ->
              %{}
          end

        data = merge(data, load_data_from_file(entity_id))

        component_mapping = Militerm.Config.master().components()

        for {module_key, ur_data} <- data do
          module = Map.get(component_mapping, as_atom(module_key), nil)

          if not is_nil(module) do
            module_data = module.get(entity_id)
            module.set(entity_id, merge(module_data, ur_data))
          end
        end

        receive_message(this, "cmd", "Updated #{entity_id}")
      else
        # uhoh - we can't find anything that matches!
        receive_message(this, "cmd:error", "No such thing exists: #{thing}")
      end
    else
      receive_message(this, "cmd:error", "You don't have permission to do that.")
    end
  end

  defp merge(a, b) when is_map(a) and is_map(b) do
    Map.merge(a, b, fn _, sa, sb -> merge(sa, sb) end)
  end

  defp merge(a, b) when is_map(a) and is_list(b) do
    if Keyword.keyword?(b), do: merge(a, Map.new(b)), else: a
  end

  defp merge(a, b) when is_list(a) and is_map(b) do
    if Keyword.keyword?(a), do: merge(Map.new(a), b), else: a
  end

  defp merge(a, b) when is_list(a) and is_list(b) do
    if Keyword.keyword?(a) and Keyword.keyword?(b),
      do: Keyword.merge(a, b),
      else: Enum.uniq(a ++ b)
  end

  defp merge(a, b), do: b

  defp as_atom(atom) when is_atom(atom), do: atom
  defp as_atom(bin) when is_binary(bin), do: String.to_atom(bin)

  def register_interface(entity_id, module) do
    case whereis(entity_id) do
      {:ok, pid} ->
        GenServer.call(pid, {:register_interface, module})

      _ ->
        :noent
    end
  end

  def unregister_interface(entity_id) do
    case whereis(entity_id) do
      {:ok, pid} ->
        GenServer.call(pid, :unregister_interface)

      _ ->
        :ok
    end
  end

  def registered_interfaces(entity_id) do
    case whereis(entity_id) do
      {:ok, pid} ->
        GenServer.call(pid, :registered_interfaces)

      _ ->
        []
    end
  end

  def hibernate({:thing, entity_id} = entity) do
    case whereis(entity) do
      {:ok, _pid} ->
        # stop the clocks/alarms
        Militerm.Components.EphemeralGroup.hibernate(entity_id)
        Militerm.Components.Entity.hibernate(entity_id)
        Militerm.Components.Location.hibernate(entity_id)

      _ ->
        :noent
    end
  end

  def unhibernate({:thing, entity_id} = entity) do
    case whereis(entity) do
      {:ok, _pid} ->
        Militerm.Components.Entity.unhibernate(entity_id)
        Militerm.Components.Location.unhibernate(entity_id)

      # start the clocks/alarms
      _ ->
        :noent
    end
  end

  def process_input(entity_id, command) do
    case whereis(entity_id) do
      {:ok, pid} ->
        GenServer.call(pid, {:process_input, command})
        :ok

      _ ->
        :noent
    end
  end

  def process_input_async(entity_id, command) do
    case whereis(entity_id) do
      {:ok, pid} ->
        GenServer.cast(pid, {:process_input, command})
        :ok

      _ ->
        :noent
    end
  end

  def receive_message(entity_id, message_type, raw_message, args \\ %{}) do
    message =
      case MML.bind(raw_message, args) do
        {:ok, binding} -> binding
        _ -> raw_message
      end

    case whereis(entity_id) do
      {:ok, pid} ->
        if pid == self() do
          Task.start(fn ->
            GenServer.call(
              pid,
              {:receive_message, message_type, message}
            )
          end)
        else
          GenServer.call(
            pid,
            {:receive_message, message_type, message}
          )
        end

        :ok

      _ ->
        :noent
    end
  end

  def shutdown(entity_id) do
    case Swarm.whereis_name(entity_id) do
      {:ok, pid} ->
        GenServer.call(pid, :shutdown)

      _ ->
        :ok
    end
  end

  def whereis({:thing, entity_id, _}), do: whereis({:thing, entity_id})

  def whereis({:thing, entity_id}) do
    # we want to find the module for the entity_id that we'll use to run events, etc.
    # the record gets created by the entity creation
    with {:ok, module} <- Militerm.Components.Entity.module(entity_id),
         {:ok, pid} <-
           Swarm.whereis_or_register_name(
             entity_id,
             Militerm.Systems.Entity.Controller,
             :start_link,
             [
               entity_id,
               module
             ]
           ) do
      {:ok, pid}
    else
      otherwise ->
        try_loading_from_files(entity_id)
    end
  end

  def whereis(_), do: nil

  def whatis(pid) when is_pid(pid) do
    GenServer.call(pid, :get_entity_id)
  end

  def load_data_from_file(<<"scene:", rest::binary>> = entity_id) do
    [domain, area | path] = String.split(rest, ":", trim: true)

    filename_base =
      Path.join([Config.game_dir(), "domains", domain, "areas", area, "scenes" | path])

    extension =
      [".mt", ".yaml"]
      |> Enum.find(&File.exists?(filename_base <> &1))

    if extension == ".yaml" do
      case YamlElixir.read_from_file(filename_base <> extension) do
        {:ok, data} -> data
        _ -> %{}
      end
    else
      %{}
    end
  end

  def try_loading_from_files(<<"scene:", rest::binary>> = entity_id) do
    [domain, area | path] = String.split(rest, ":", trim: true)

    filename_base =
      Path.join([Config.game_dir(), "domains", domain, "areas", area, "scenes" | path])

    extension =
      [".mt", ".yaml"]
      |> Enum.find(&File.exists?(filename_base <> &1))

    result =
      case extension do
        ".mt" ->
          Militerm.Entities.Scene.create(entity_id, entity_id)

        ".yaml" ->
          # use "std:scene" as the archetype
          # data = YamlElixir.read
          result =
            case YamlElixir.read_from_file(filename_base <> extension) do
              {:ok, %{"archetype" => archetype} = data} ->
                Militerm.Entities.Scene.create(entity_id, archetype, data)

              {:ok, data} ->
                Militerm.Entities.Scene.create(entity_id, "std:scene", data)

              {:error, message} ->
                Logger.warn("Unable to read #{filename_base}#{extension}: #{inspect(message)}")
                nil
            end

        _ ->
          nil
      end

    if !is_nil(result) do
      Swarm.whereis_or_register_name(
        entity_id,
        Militerm.Systems.Entity.Controller,
        :start_link,
        [
          entity_id,
          Militerm.Entities.Scene
        ]
      )
    end
  end

  def try_loading_from_files(_), do: nil
end

defmodule Militerm.Systems.Entity do
  use Militerm.ECS.System

  alias Militerm.Config
  alias Militerm.Systems.MML
  alias Militerm.Systems.Entity.Controller

  require Logger

  @moduledoc """
  Manages control of an entity -- managing events more than anything else.
  """

  defdelegate set_property(entity_id, path, value, args), to: Controller
  defdelegate reset_property(entity_id, path, args), to: Controller
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
  defdelegate get_context(entity_id), to: Controller
  defdelegate set_context(entity_id, context), to: Controller

  def register_interface(entity_id, module) do
    with {:ok, pid} <- whereis(entity_id) do
      GenServer.call(pid, {:register_interface, module})
    else
      _ -> :noent
    end
  end

  def unregister_interface(entity_id) do
    with {:ok, pid} <- whereis(entity_id) do
      GenServer.call(pid, :unregister_interface)
    else
      _ -> :ok
    end
  end

  def registered_interfaces(entity_id) do
    with {:ok, pid} <- whereis(entity_id) do
      GenServer.call(pid, :registered_interfaces)
    else
      _ -> []
    end
  end

  def hibernate({:thing, entity_id} = entity) do
    with {:ok, pid} <- whereis(entity) do
      # TODO: stop the clocks/alarms
      Militerm.Components.Entity.hibernate(entity_id)
      Militerm.Components.Location.hibernate(entity_id)
    else
      _ -> :noent
    end
  end

  def unhibernate({:thing, entity_id} = entity) do
    with {:ok, pid} <- whereis(entity) do
      Militerm.Components.Entity.unhibernate(entity_id)
      Militerm.Components.Location.unhibernate(entity_id)

      # TODO: start the clocks/alarms
    else
      _ -> :noent
    end
  end

  def process_input(entity_id, command) do
    with {:ok, pid} <- whereis(entity_id) do
      GenServer.cast(pid, {:process_input, command})
      :ok
    else
      _ -> :noent
    end
  end

  def receive_message(entity_id, message_type, raw_message, args \\ %{}) do
    message =
      case Militerm.Systems.MML.bind(raw_message, args) do
        {:ok, binding} -> binding
        _ -> raw_message
      end

    with {:ok, pid} <- whereis(entity_id) do
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
    else
      _ -> :noent
    end
  end

  def shutdown(entity_id) do
    with {:ok, pid} <- Swarm.whereis_name(entity_id) do
      GenServer.call(pid, :shutdown)
    else
      _ -> :ok
    end
  end

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
        Logger.debug(inspect(otherwise))
        nil
    end
  end

  def whereis(_), do: nil
end

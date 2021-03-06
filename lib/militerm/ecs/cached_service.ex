defmodule Militerm.ECS.CachedService do
  @moduledoc """
  The component service tracks component data for entities.

  For example, if you have a component named MyGame.Components.Health, you
  can start a copy of this with:

      Militerm.ECS.Component.start_link(name: MyGame.Components.Health)

  Then, later, you can set or get the data for the component:

      Militerm.ECS.Component.set(MyGame.Components.Health, entity_id, %{hp: 100, max_hp: 100})
      %{hp: hp, max_hp: hp} = Militerm.ECS.Component.get(MyGame.Components.Health, entity_id)

  Each component defines its persistance mechanisms through the `store/2`, `update/3`, `fetch/1`,
  `delete/1`, and `clear/0` functions. These are required and do not have default definitions.
  """

  @type callback :: {mfa, [term]} | function
  @type path :: String.t() | [String.t()]

  @callback set(term) :: :ok
  @callback set(term, map) :: :ok
  @callback get(term) :: map
  @callback get(term, map) :: map
  @callback update(term, callback) :: :ok
  @callback remove(term) :: :ok
  @callback reset() :: :ok

  @callback store(term, term) :: :ok
  @callback update(term, term, term) :: :ok
  @callback fetch(term) :: term
  @callback delete(term) :: :ok
  @callback clear() :: :ok

  defmacro __using__(opts) do
    quote do
      # @behaviour Militerm.ECS.Component

      def child_spec(opts \\ []) do
        %{
          id: __MODULE__,
          start: {Cachex, :start_link, [__MODULE__, [fallback: &__MODULE__.fetch(&1)]]},
          type: :worker,
          restart: :permanent,
          shutdown: 500
        }
      end

      def set(thing), do: set(thing, @default)
      def set(thing, data), do: Militerm.ECS.Component.set(__MODULE__, thing, data)
      def get(thing), do: Militerm.ECS.Component.get(__MODULE__, thing, @default)
      def get(thing, default), do: Militerm.ECS.Component.get(__MODULE__, thing, default)
      def update(thing, callback), do: Militerm.ECS.Component.update(__MODULE__, thing, callback)
      def remove(thing), do: Militerm.ECS.Component.remove(__MODULE__, thing)
      def reset(), do: Militerm.ECS.Component.reset(__MODULE__)

      defoverridable child_spec: 1, set: 1, set: 2, get: 1, get: 2, update: 2, remove: 1, reset: 0
    end
  end

  ###
  ### Public API
  ###

  @doc """
  ## Example
    iex> Service.Levels.set("123", %{xp: 123, level: 2})
    :ok
  """
  def set(component, thing, data) do
    Cachex.transaction!(component, [thing], fn cache ->
      Cachex.put(cache, thing, data)
      apply(component, :store, [thing, data])
    end)
  end

  @doc """
  ## Example
    iex> Component.Levels.set("123", %{xp: 123, level: 2})
    :ok
    iex> Component.Levels.get("123")
    %{xp: 123, level: 2}
  """
  def get(component, thing, default \\ %{}) do
    case Cachex.get(component, thing) do
      {:ok, nil} ->
        # fetch and store
        case component.fetch(thing) do
          nil ->
            default

          value ->
            Cachex.put(component, thing, value)
            value
        end

      {:ok, value} ->
        value

      {:error, _} ->
        default
    end
  end

  @doc """
  ## Examples
    iex> Component.Levels.set("123", %{xp: 123, level: 2})
    :ok
    iex> Component.Levels.update("123", fn %{xp: xp} = data ->
    ...>   %{data | xp: xp + 10}
    ...> end)
    :ok
    iex> Component.Levels.get("123")
    %{xp: 133, level: 2}
  """
  def update(component, thing, callback) do
    Cachex.transaction!(component, [thing], fn cache ->
      current_data =
        case Cachex.get(cache, thing) do
          {:ok, value} -> value
          {:error, _} -> nil
        end

      case {current_data, execute_callback(callback, current_data)} do
        {nil, nil} ->
          :ok

        {_, nil} ->
          Cachex.del(cache, thing)
          apply(component, :delete, [thing])
          :ok

        # no change
        {x, x} ->
          :ok

        {old_data, new_data} ->
          Cachex.put(cache, thing, new_data)
          apply(component, :update, [thing, old_data, new_data])
          :ok
      end
    end)
  end

  defp execute_callback(callback, arg) when is_function(callback) do
    callback.(arg)
  end

  defp execute_callback({{m, f, _}, a}, arg) do
    apply(m, f, [arg | a])
  end

  @doc """
    iex> Component.Levels.set("123", %{xp: 123, level: 2})
    :ok
    iex> Component.Levels.get("123")
    %{xp: 123, level: 2}
    iex> Component.Levels.remove("123")
    :ok
    iex> Component.Levels.get("123", nil)
    nil
  """
  def remove(component, thing) do
    Cachex.transaction!(component, [thing], fn cache ->
      {:ok, true} = Cachex.del(cache, thing)
      apply(component, :delete, [thing])
    end)

    :ok
  end

  def reset(component) do
    Cachex.reset(component)
    apply(component, :clear, [])
  end
end
